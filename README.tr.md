# AiWingman — macOS için İş Sürekliliği

AiWingman, paralel Codex görevleri arasında doğru işe geri dönmeyi kolaylaştıran yerel ve native bir macOS menü çubuğu uygulamasıdır. Dashboard, Codex’in `~/.codex` altındaki yerel kayıtlarını salt okunur inceler ve ağ isteği yapmaz. Yalnız isteğe bağlı Wingman eleştirisi, tam JSON paket önizlemesi ve tek kullanımlık açık onaydan sonra ayrı kurulmuş ve giriş yapılmış Codex CLI üzerinden Codex/OpenAI işlemeyi kullanır; AiWingman hesabı veya ayrı bir API anahtarı istemez, saklamaz ya da yönetmez. Kayıtlı CLI kimlik doğrulama mekanizmasını içeriğini ayrıştırmadan yeniden kullanır.

[Kurulum](INSTALL.tr.md) · [English installation](INSTALL.md) · [Gizlilik](PRIVACY.md) · [Katkı](CONTRIBUTING.md)

> **GÜVENLİK BEKLEMESİ:** `v1.2.0-beta.2` ve bu etiketle eşleşen ana dal görüntüsü geçersiz kılındı. Derlemeyin veya kullanmayın. Sonraki inceleme; eksik yol sınırlandırması, sınırsız session-index okumaları, doğrulanamayan geçici kimlik doğrulama temizliği ve fazla geniş gizlilik ifadeleri dahil olmak üzere sürümü engelleyen kusurlar buldu. [Beta2 release sayfası](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) aynı uyarıyı taşır. Güçlendirilmiş kaynak adayı incelemeyi bitirene kadar desteklenen public tag yoktur.

## Temel özellikler

- Kullanıcıya ait üst seviye Codex görevlerini tek yerde gösterir.
- Bekleyen kullanıcı girdisini, blokajı ve görülmemiş sonuçları ayırır.
- Sessizliği “çalışıyor” ya da “terk edilmiş” diye yorumlamaz.
- Bir işi checkpoint ve tek sonraki adımla park etmeyi sağlar.
- Kanıt yetersizse görev sıralamaktan açıkça kaçınır.
- Obsolete ve terk edilmiş gibi yüksek etkili kararları yalnız kullanıcı onayıyla uygular ve geri alınabilir tutar.
- Seçilen görevi `codex://threads/<id>` ile Codex’te açar.
- Dashboard, editör, durum menüsü ve Wingman arayüzünü TR/EN arasında anında
  değiştirir; yerel seçimi sonraki açılış için hatırlar.
- İstenirse prompting, harness, yarım kalan işler ve token inceleme adayları
  için ayrı bir Codex CLI Wingman turu başlatır.
- Dashboard ağ isteği yapmaz ve arka planda ajan çağrısı başlatmaz. Bu
  geçersiz kılınmış sürüm, `~/.codex` altındaki SQLite WAL yan dosyaları için
  yazmama garantisi oluşturmaz.

## Gereksinimler

- macOS 13 veya üzeri.
- Aynı macOS hesabında daha önce kullanılmış Codex Desktop veya Codex CLI.
- Kaynaktan derleme için güncel Xcode ya da uyumlu Swift araç zinciri.
- Yalnız isteğe bağlı uzak Wingman eleştirisi için ayrıca uyumlu, ayrı kurulmuş
  ve giriş yapılmış Codex CLI; dashboard için gerekmez.

Uzak çağrıdan önce AiWingman, stdin üzerinden vermeyi amaçladığı kullanıcı-
türevi JSON paketinin tamamını gösterir ve her çağrı için tek kullanımlık açık
onay ister. Paket, kaynakta bulunan ve görev verisi içermeyen sabit inceleme
talimatı ile çıktı şemasıyla birlikte işlenir.
Bu geçersiz kılınmış dalın metnini paket alanlarının eksiksiz tanımı olarak
kabul etmeyin; her isteğe bağlı çağrıdan önce tek kullanımlık önizlemeyi
inceleyin. AiWingman CLI’ın salt-okunur sandbox modunu ister; bu OS düzeyinde
izolasyon veya sıfır dosya yazma garantisi değildir ve child process’in başka
yerel dosyaları okuyamayacağını da kanıtlamaz. Bu nedenle önizlenen paket, CLI’ın teknik
olarak erişebileceği tek bağlam gibi değerlendirilmemelidir.

Şu anda desteklenen public derleme veya tag yoktur. `v1.2.0-beta.2` ya da bu
hareketli ana dal görüntüsünden derlemeyin. GitHub kaynak arşivini “çift tıkla
kurulum” paketi olarak değerlendirmeyin. Güncel dağıtım durumu ana
[README](README.md) ve release notlarında açıkça belirtilir.

İmzalı bir sürüm yayımlandığında checksum, Gatekeeper, ilk açılış, güncelleme ve kaldırma adımlarını [Türkçe kurulum kılavuzundan](INSTALL.tr.md) izleyin.

## Yerel doğrulama

```bash
swift run ActivityRadarSelfTest
swift run ActivityRadarDiagnostics
```

AiWingman, mevcut Activity Radar kullanıcılarının verisini kaybetmemesi için
`ActivityRadar` executable adını, eski bundle kimliklerini, tercih anahtarlarını
ve `~/Library/Application Support/Activity Radar` yolunu uyumluluk amacıyla
korur. Bunlar ikinci bir uygulama değil, eski teknik kimliklerdir.

Tanılama komutu yalnız içeriksiz toplu uyumluluk sayaçları üretir. Görev başlığı, mesaj, dosya yolu, checkpoint veya ham görev kimliği içermez.

Kaynaktan paketlediğiniz uygulama Dock’ta görünmez; AiWingman bir menü
çubuğu uygulamasıdır. Açtıktan sonra menü çubuğundaki radar simgesini kullanın
veya paneli `⌘⇧K` ile çağırın. Bu yerel ad-hoc paket, halka açık imzalı sürüm
yerine geçmez.

Bağlantının nasıl çalıştığı için [Codex entegrasyonu](docs/CODEX_INTEGRATION.md), veri sınırları için [PRIVACY.md](PRIVACY.md), katkı için [CONTRIBUTING.md](CONTRIBUTING.md), araştırmada atıf için [CITATION.cff](CITATION.cff) dosyasına bakın.

AiWingman bağımsız ve resmi olmayan bir topluluk projesidir; OpenAI tarafından yayımlanan veya desteklenen resmi bir ürün değildir. Uzak Wingman çağrısı kullanıcının mevcut Codex CLI hesabını kullanır ve o hesabın plan/kotasından tüketebilir; AiWingman’ın kendisi ücretsizdir.
