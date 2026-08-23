# AiWingman — macOS için İş Sürekliliği

AiWingman, paralel Codex görevleri arasında doğru işe geri dönmeyi kolaylaştıran yerel ve native bir macOS menü çubuğu uygulamasıdır. Dashboard, Codex’in `~/.codex` altındaki yerel kayıtlarını salt okunur inceler ve ağ isteği yapmaz. Yalnız isteğe bağlı Wingman eleştirisi, tam JSON paket önizlemesi ve tek kullanımlık açık onaydan sonra ayrı kurulmuş ve giriş yapılmış Codex CLI üzerinden Codex/OpenAI işlemeyi kullanır; AiWingman hesabı veya ayrı bir API anahtarı istemez, saklamaz ya da yönetmez. Kayıtlı CLI kimlik doğrulama mekanizmasını içeriğini ayrıştırmadan yeniden kullanır.

[Kurulum](INSTALL.tr.md) · [English installation](INSTALL.md) · [Gizlilik](PRIVACY.md) · [Katkı](CONTRIBUTING.md)

[`v1.2.0-beta.2`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) ücretsiz, kaynak-öncelikli topluluk betasıdır. Hazır uygulama paketi içermez; exact tag’i inceleyip aşağıdaki komutlarla kendi Mac’inizde derleyebilirsiniz. GitHub’ın otomatik kaynak arşivleri macOS yükleyicisi değildir.

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
- Dashboard ağ isteği yapmaz; AiWingman hiçbir özellikte
  `~/.codex` içine yazmaz ve arka planda ajan çağrısı başlatmaz.

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
Ham prompt örnekleri, prompt-türevi temalar ve yerel metin sinyalleri tek bir
ayrı seçenekle ve varsayılanı kapalı olarak paylaşılır. Seçenek kapalıyken uzak
paket yalnız görev başlıkları ve sayısal ölçümler taşır. Salt-okunur
CLI sandbox’ı yazmayı engeller; fakat child process’in başka yerel dosyaları
okuyamayacağının garantisi değildir. Bu nedenle önizlenen paket, CLI’ın teknik
olarak erişebileceği tek bağlam gibi değerlendirilmemelidir.

Bu beta kaynaktan kurulur; GitHub kaynak arşivini “çift tıkla kurulum” paketi olarak değerlendirmeyin. Güncel dağıtım durumu ana [README](README.md) ve release notlarında açıkça belirtilir.

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
