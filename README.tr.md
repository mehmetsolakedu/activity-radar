# Activity Radar — macOS için İş Sürekliliği

Activity Radar, paralel Codex görevleri arasında doğru işe geri dönmeyi kolaylaştıran yerel ve native bir macOS menü çubuğu uygulamasıdır. Codex’in `~/.codex` altındaki yerel kayıtlarını salt okunur inceler; OpenAI API anahtarı, Activity Radar hesabı veya bulut servisi kullanmaz.

## Temel özellikler

- Kullanıcıya ait üst seviye Codex görevlerini tek yerde gösterir.
- Bekleyen kullanıcı girdisini, blokajı ve görülmemiş sonuçları ayırır.
- Sessizliği “çalışıyor” ya da “terk edilmiş” diye yorumlamaz.
- Bir işi checkpoint ve tek sonraki adımla park etmeyi sağlar.
- Kanıt yetersizse görev sıralamaktan açıkça kaçınır.
- Obsolete ve terk edilmiş gibi yüksek etkili kararları yalnız kullanıcı onayıyla uygular ve geri alınabilir tutar.
- Seçilen görevi `codex://threads/<id>` ile Codex’te açar.
- Ağ isteği yapmaz ve `~/.codex` içine yazmaz.

## Gereksinimler

- macOS 13 veya üzeri.
- Aynı macOS hesabında daha önce kullanılmış Codex Desktop veya Codex CLI.
- Kaynaktan derleme için güncel Xcode ya da uyumlu Swift araç zinciri.

İmzalı ve Apple tarafından noterlenmiş bir binary yayımlanmadan önce GitHub’daki kaynak paketini “çift tıkla kurulum” sürümü olarak değerlendirmeyin. Güncel dağıtım durumu ana [README](README.md) ve release notlarında açıkça belirtilir.

## Yerel doğrulama

```bash
swift run ActivityRadarSelfTest
swift run ActivityRadarDiagnostics
```

Tanılama komutu yalnız içeriksiz toplu uyumluluk sayaçları üretir. Görev başlığı, mesaj, dosya yolu, checkpoint veya ham görev kimliği içermez.

Bağlantının nasıl çalıştığı için [Codex entegrasyonu](docs/CODEX_INTEGRATION.md), veri sınırları için [PRIVACY.md](PRIVACY.md), katkı için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

Activity Radar bağımsız ve resmi olmayan bir topluluk projesidir; OpenAI tarafından yayımlanan veya desteklenen resmi bir ürün değildir.
