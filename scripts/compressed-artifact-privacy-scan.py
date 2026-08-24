#!/usr/bin/env python3
"""Fail-closed privacy scan for compressed DOCX and PDF artifact content."""

from __future__ import annotations

import base64
import os
import re
import stat
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib
from pathlib import Path, PurePosixPath


MAX_DOCX_MEMBERS = 512
MAX_DOCX_ARCHIVE_BYTES = 64 * 1024 * 1024
MAX_DOCX_MEMBER_BYTES = 32 * 1024 * 1024
MAX_DOCX_TOTAL_BYTES = 128 * 1024 * 1024
MAX_PDF_BYTES = 64 * 1024 * 1024
MAX_PDF_STREAMS = 2_048
MAX_PDF_DICTIONARY_BYTES = 64 * 1024
MAX_PDF_DECODED_STREAM_BYTES = 64 * 1024 * 1024
MAX_PDF_TOTAL_DECODED_BYTES = 256 * 1024 * 1024

PRIVATE_HOME_PATTERN = re.compile(rb"/(?:Users|home)/[^/\x00-\x1f\x7f]+")
TASK_ID_PATTERN = re.compile(rb"codex://threads/[0-9a-fA-F-]{24,}")
UUID_PATTERN = re.compile(
    rb"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    rb"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)
CREDENTIAL_PATTERN = re.compile(
    rb"(?:gh[pousr]_[A-Za-z0-9_]{20,}|"
    rb"github_pat_[A-Za-z0-9_]{20,}|"
    rb"sk-[A-Za-z0-9_-]{20,}|"
    rb"AKIA[0-9A-Z]{16}|"
    rb"BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY)"
)

ALLOWED_HOME_MATCHES = {
    b"/" b"Users/example",
    b"/" b"Users/private-person",
    b"/" b"Users/synthetic-user",
    b"/" b"Users/test-user",
    b"/" b"home/example",
    b"/" b"home/private-person",
    b"/" b"home/synthetic-user",
    b"/" b"home/test-user",
}
ALLOWED_TASK_ID = b"codex://threads/123e4567-e89b-42d3-a456-426614174000"
ALLOWED_UUID = b"123e4567-e89b-42d3-a456-426614174000"

PDF_STREAM_PATTERN = re.compile(rb"(?<![A-Za-z])stream(?:\r\n|\n|\r)")
PDF_FILTER_PATTERN = re.compile(
    rb"/Filter(?![A-Za-z0-9])\s*(\[[^\]]*\]|/[A-Za-z0-9]+)",
    re.DOTALL,
)
PDF_LENGTH_PATTERN = re.compile(
    rb"/Length(?![A-Za-z0-9])\s+(\d+)(?:\s+(\d+)\s+R)?"
)
PDF_SCALAR_OBJECT_PATTERN = re.compile(
    rb"(?m)^\s*(\d+)\s+(\d+)\s+obj\s*(\d+)\s*endobj"
)


class PrivacyViolation(Exception):
    def __init__(self, category: str, artifact: str, surface: str) -> None:
        self.category = category
        self.artifact = artifact
        self.surface = surface
        super().__init__(category)


class ArtifactScanError(Exception):
    pass


def scan_surface(data: bytes, artifact: str, surface: str) -> None:
    for match in PRIVATE_HOME_PATTERN.finditer(data):
        if match.group(0) not in ALLOWED_HOME_MATCHES:
            raise PrivacyViolation("private home path", artifact, surface)

    for match in TASK_ID_PATTERN.finditer(data):
        if match.group(0).lower() != ALLOWED_TASK_ID:
            raise PrivacyViolation("task URI", artifact, surface)

    if CREDENTIAL_PATTERN.search(data):
        raise PrivacyViolation("credential pattern", artifact, surface)

    for match in UUID_PATTERN.finditer(data):
        if match.group(0).lower() != ALLOWED_UUID:
            raise PrivacyViolation("non-synthetic UUID", artifact, surface)


def artifact_label(root: Path, artifact: Path) -> str:
    try:
        return artifact.relative_to(root).as_posix()
    except ValueError:
        return artifact.name


def validate_docx_member_name(name: str) -> None:
    member_path = PurePosixPath(name)
    if (
        not name
        or "\x00" in name
        or "\\" in name
        or member_path.is_absolute()
        or any(part in {"", ".", ".."} for part in member_path.parts)
    ):
        raise ArtifactScanError("DOCX contains an unsafe ZIP member name")


def read_docx_member(archive: zipfile.ZipFile, info: zipfile.ZipInfo) -> bytes:
    if info.flag_bits & 0x1:
        raise ArtifactScanError("DOCX contains an encrypted ZIP member")
    if info.file_size > MAX_DOCX_MEMBER_BYTES:
        raise ArtifactScanError("DOCX member exceeds the scan size limit")

    chunks: list[bytes] = []
    byte_count = 0
    try:
        with archive.open(info, "r") as member:
            while True:
                chunk = member.read(64 * 1024)
                if not chunk:
                    break
                byte_count += len(chunk)
                if byte_count > MAX_DOCX_MEMBER_BYTES:
                    raise ArtifactScanError("DOCX member exceeds the scan size limit")
                chunks.append(chunk)
    except (RuntimeError, NotImplementedError, OSError, zipfile.BadZipFile) as error:
        raise ArtifactScanError("DOCX member could not be decompressed") from error

    if byte_count != info.file_size:
        raise ArtifactScanError("DOCX member size disagrees with its ZIP metadata")
    return b"".join(chunks)


def scan_xml_member(data: bytes, artifact: str, surface: str) -> None:
    if b"<!DOCTYPE" in data.upper() or b"<!ENTITY" in data.upper():
        raise ArtifactScanError("DOCX XML contains a forbidden declaration")
    try:
        root = ET.fromstring(data)
    except (ET.ParseError, LookupError, ValueError) as error:
        raise ArtifactScanError("DOCX XML member is malformed") from error

    pieces: list[str] = []
    for element in root.iter():
        if element.text:
            pieces.append(element.text)
        for value in element.attrib.values():
            pieces.append(value)
        if element.tail:
            pieces.append(element.tail)

    if pieces:
        scan_surface("".join(pieces).encode("utf-8"), artifact, surface + " XML text")
        scan_surface("\n".join(pieces).encode("utf-8"), artifact, surface + " XML values")


def scan_docx(root: Path, artifact: Path) -> None:
    label = artifact_label(root, artifact)
    try:
        if artifact.is_symlink() or not artifact.is_file():
            raise ArtifactScanError("DOCX artifact is not a regular non-symlink file")
        archive_size = artifact.stat().st_size
        if archive_size <= 0 or archive_size > MAX_DOCX_ARCHIVE_BYTES:
            raise ArtifactScanError("DOCX archive size is outside the scan limit")
        with zipfile.ZipFile(artifact, "r") as archive:
            members = archive.infolist()
            if not members or len(members) > MAX_DOCX_MEMBERS:
                raise ArtifactScanError("DOCX member count is outside the scan limit")

            seen_names: set[str] = set()
            total_size = 0
            for index, info in enumerate(members, start=1):
                validate_docx_member_name(info.filename)
                if info.filename in seen_names:
                    raise ArtifactScanError("DOCX contains duplicate ZIP member names")
                seen_names.add(info.filename)

                unix_mode = (info.external_attr >> 16) & 0xFFFF
                if unix_mode and stat.S_ISLNK(unix_mode):
                    raise ArtifactScanError("DOCX contains a symbolic-link ZIP member")
                if info.is_dir():
                    continue

                total_size += info.file_size
                if total_size > MAX_DOCX_TOTAL_BYTES:
                    raise ArtifactScanError("DOCX exceeds the total scan size limit")

                member_data = read_docx_member(archive, info)
                surface = f"DOCX member {index}"
                scan_surface(info.filename.encode("utf-8"), label, surface + " name")
                scan_surface(member_data, label, surface)
                lowered_name = info.filename.lower()
                if lowered_name.endswith(".xml") or lowered_name.endswith(".rels"):
                    scan_xml_member(member_data, label, surface)
    except zipfile.BadZipFile as error:
        raise ArtifactScanError("DOCX is not a valid ZIP archive") from error


def find_pdf_dictionary(data: bytes, stream_keyword_start: int) -> bytes:
    lower_bound = max(0, stream_keyword_start - MAX_PDF_DICTIONARY_BYTES)
    dictionary_end = data.rfind(b">>", lower_bound, stream_keyword_start)
    if dictionary_end < 0 or data[dictionary_end + 2 : stream_keyword_start].strip():
        raise ArtifactScanError("PDF stream has no adjacent dictionary")

    tokens = list(re.finditer(rb"<<|>>", data[lower_bound : dictionary_end + 2]))
    depth = 0
    dictionary_start = -1
    for token in reversed(tokens):
        if token.group(0) == b">>":
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                dictionary_start = lower_bound + token.start()
                break
    if dictionary_start < 0:
        raise ArtifactScanError("PDF stream dictionary is unbalanced or too large")
    return data[dictionary_start : dictionary_end + 2]


def pdf_scalar_lengths(data: bytes) -> dict[tuple[int, int], int]:
    lengths: dict[tuple[int, int], int] = {}
    for match in PDF_SCALAR_OBJECT_PATTERN.finditer(data):
        key = (int(match.group(1)), int(match.group(2)))
        value = int(match.group(3))
        if key in lengths and lengths[key] != value:
            raise ArtifactScanError("PDF contains conflicting scalar objects")
        lengths[key] = value
    return lengths


def pdf_stream_length(
    dictionary: bytes, scalar_lengths: dict[tuple[int, int], int]
) -> int:
    matches = list(PDF_LENGTH_PATTERN.finditer(dictionary))
    if len(matches) != 1:
        raise ArtifactScanError("PDF stream does not have one resolvable length")
    match = matches[0]
    first_number = int(match.group(1))
    generation = match.group(2)
    if generation is None:
        length = first_number
    else:
        key = (first_number, int(generation))
        if key not in scalar_lengths:
            raise ArtifactScanError("PDF stream length reference cannot be resolved")
        length = scalar_lengths[key]
    if length < 0 or length > MAX_PDF_BYTES:
        raise ArtifactScanError("PDF encoded stream exceeds the scan size limit")
    return length


def pdf_filters(dictionary: bytes) -> list[bytes]:
    matches = list(PDF_FILTER_PATTERN.finditer(dictionary))
    if not matches:
        if b"/Filter" in dictionary:
            raise ArtifactScanError("PDF uses an unsupported filter declaration")
        return []
    if len(matches) != 1:
        raise ArtifactScanError("PDF stream has multiple filter declarations")

    declaration = matches[0].group(1)
    names = re.findall(rb"/([A-Za-z0-9]+)", declaration)
    remainder = re.sub(rb"/[A-Za-z0-9]+", b"", declaration)
    remainder = remainder.replace(b"[", b"").replace(b"]", b"")
    if remainder.strip() or not names:
        raise ArtifactScanError("PDF uses an unsupported filter declaration")
    return names


def decode_ascii85(data: bytes) -> bytes:
    compact = re.sub(rb"[\x00\t\n\f\r ]+", b"", data)
    if compact.startswith(b"<~"):
        compact = compact[2:]
    if compact.endswith(b"~>"):
        compact = compact[:-2]
    try:
        return base64.a85decode(compact, adobe=False)
    except (ValueError, OverflowError) as error:
        raise ArtifactScanError("PDF ASCII85 stream could not be decoded") from error


def decode_ascii_hex(data: bytes) -> bytes:
    compact = re.sub(rb"[\x00\t\n\f\r ]+", b"", data)
    if compact.endswith(b">"):
        compact = compact[:-1]
    if len(compact) % 2:
        compact += b"0"
    try:
        return bytes.fromhex(compact.decode("ascii"))
    except (UnicodeDecodeError, ValueError) as error:
        raise ArtifactScanError("PDF ASCIIHex stream could not be decoded") from error


def decode_flate(data: bytes) -> bytes:
    decompressor = zlib.decompressobj()
    output = bytearray()
    try:
        for offset in range(0, len(data), 64 * 1024):
            remaining = MAX_PDF_DECODED_STREAM_BYTES - len(output)
            if remaining < 0:
                raise ArtifactScanError("PDF decoded stream exceeds the scan size limit")
            output.extend(decompressor.decompress(data[offset : offset + 64 * 1024], remaining + 1))
            if len(output) > MAX_PDF_DECODED_STREAM_BYTES or decompressor.unconsumed_tail:
                raise ArtifactScanError("PDF decoded stream exceeds the scan size limit")
        remaining = MAX_PDF_DECODED_STREAM_BYTES - len(output)
        output.extend(decompressor.flush(remaining + 1))
    except zlib.error as error:
        raise ArtifactScanError("PDF Flate stream could not be decoded") from error
    if (
        len(output) > MAX_PDF_DECODED_STREAM_BYTES
        or not decompressor.eof
        or decompressor.unused_data
    ):
        raise ArtifactScanError("PDF Flate stream is truncated or exceeds the scan size limit")
    return bytes(output)


def decode_pdf_stream(encoded: bytes, filters: list[bytes]) -> bytes:
    decoded = encoded
    for filter_name in filters:
        if filter_name in {b"ASCII85Decode", b"A85"}:
            decoded = decode_ascii85(decoded)
        elif filter_name in {b"ASCIIHexDecode", b"AHx"}:
            decoded = decode_ascii_hex(decoded)
        elif filter_name in {b"FlateDecode", b"Fl"}:
            decoded = decode_flate(decoded)
        else:
            raise ArtifactScanError("PDF stream uses an unsupported filter")
        if len(decoded) > MAX_PDF_DECODED_STREAM_BYTES:
            raise ArtifactScanError("PDF decoded stream exceeds the scan size limit")
    return decoded


def scan_pdf(root: Path, artifact: Path) -> None:
    label = artifact_label(root, artifact)
    if artifact.is_symlink() or not artifact.is_file():
        raise ArtifactScanError("PDF artifact is not a regular non-symlink file")
    try:
        file_size = artifact.stat().st_size
        if file_size <= 0 or file_size > MAX_PDF_BYTES:
            raise ArtifactScanError("PDF size is outside the scan limit")
        data = artifact.read_bytes()
    except OSError as error:
        raise ArtifactScanError("PDF could not be read") from error
    if len(data) != file_size or not data.startswith(b"%PDF-"):
        raise ArtifactScanError("PDF header or size is invalid")
    if b"/Encrypt" in data:
        raise ArtifactScanError("Encrypted PDFs are not accepted")

    scan_surface(data, label, "PDF file bytes")
    scalar_lengths = pdf_scalar_lengths(data)
    cursor = 0
    stream_count = 0
    decoded_total = 0
    while True:
        match = PDF_STREAM_PATTERN.search(data, cursor)
        if match is None:
            break
        stream_count += 1
        if stream_count > MAX_PDF_STREAMS:
            raise ArtifactScanError("PDF stream count exceeds the scan limit")

        dictionary = find_pdf_dictionary(data, match.start())
        encoded_length = pdf_stream_length(dictionary, scalar_lengths)
        encoded_start = match.end()
        encoded_end = encoded_start + encoded_length
        if encoded_end > len(data):
            raise ArtifactScanError("PDF stream length exceeds the file boundary")

        endstream_start = encoded_end
        if data.startswith(b"\r\n", endstream_start):
            endstream_start += 2
        elif data.startswith((b"\r", b"\n"), endstream_start):
            endstream_start += 1
        if not data.startswith(b"endstream", endstream_start):
            raise ArtifactScanError("PDF stream length does not end at endstream")

        decoded = decode_pdf_stream(
            data[encoded_start:encoded_end], pdf_filters(dictionary)
        )
        decoded_total += len(decoded)
        if decoded_total > MAX_PDF_TOTAL_DECODED_BYTES:
            raise ArtifactScanError("PDF total decoded data exceeds the scan limit")
        scan_surface(decoded, label, f"PDF decoded stream {stream_count}")
        cursor = endstream_start + len(b"endstream")


def iter_artifacts(root: Path) -> list[Path]:
    artifacts: list[Path] = []

    def walk_error(error: OSError) -> None:
        raise ArtifactScanError("Artifact tree could not be enumerated") from error

    for directory, directory_names, file_names in os.walk(
        root, followlinks=False, onerror=walk_error
    ):
        current = Path(directory)
        for name in list(directory_names):
            candidate = current / name
            if candidate.is_symlink():
                raise ArtifactScanError("Artifact tree contains a symbolic-link directory")
        for name in file_names:
            candidate = current / name
            if candidate.suffix.lower() in {".docx", ".pdf"}:
                artifacts.append(candidate)
    return sorted(artifacts, key=lambda item: item.as_posix())


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: compressed-artifact-privacy-scan.py /path/to/public-tree", file=sys.stderr)
        return 2
    root = Path(argv[1]).resolve()
    if not root.is_dir():
        print("Compressed artifact privacy root is not a directory.", file=sys.stderr)
        return 2

    try:
        for artifact in iter_artifacts(root):
            if artifact.suffix.lower() == ".docx":
                scan_docx(root, artifact)
            else:
                scan_pdf(root, artifact)
    except PrivacyViolation as error:
        print(
            "Compressed artifact privacy scan found "
            f"{error.category} in {error.artifact} ({error.surface}); "
            "matched content suppressed.",
            file=sys.stderr,
        )
        return 5
    except ArtifactScanError as error:
        print(f"Compressed artifact privacy scan failed closed: {error}", file=sys.stderr)
        return 6
    except OSError:
        print("Compressed artifact privacy scan failed closed on a filesystem error.", file=sys.stderr)
        return 6
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
