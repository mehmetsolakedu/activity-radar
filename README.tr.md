# AiWingman — macOS için İş Sürekliliği

AiWingman, aday Codex görevleri için süreklilik kanıtlarını gösteren yerel ve native bir macOS menü çubuğu uygulamasıdır. Dashboard, Codex’in `~/.codex` altındaki yerel kayıtlarını salt-okunur/query-only SQL erişimiyle inceler ve ağ isteği yapmaz; macOS’tan Codex’in kullanıcı tarafından seçilen görevi açmasını ister. Yalnız isteğe bağlı Wingman eleştirisi, tam JSON paket önizlemesi ve tek kullanımlık açık onaydan sonra ayrı kurulmuş ve giriş yapılmış Codex CLI üzerinden Codex/OpenAI işlemeyi kullanır; AiWingman hesabı veya ayrı bir API anahtarı istemez, saklamaz ya da yönetmez. Kayıtlı CLI kimlik doğrulama mekanizmasını içeriğini ayrıştırmadan yeniden kullanır.

[Kurulum](INSTALL.tr.md) · [English installation](INSTALL.md) · [Gizlilik](PRIVACY.md) · [Katkı](CONTRIBUTING.md)

[`v1.2.0-beta.2`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2) yürürlükten kaldırılmıştır; derlenmemeli veya kullanılmamalıdır. İmzasız annotated tag şu anda `5e212181ae177cd555ab6bb92f5f71ac8be9173a` commit’ine çözülür; sonraki sertleştirme bu commit’teki veritabanı-kontrollü rollout yolu güveni, sınırsız session-index okuması ve doğrulanamayan geçici kimlik temizliği sorunlarını düzeltti. Değiştirilebilir release sayfası artık güvenlik ve belge düzeltmesini taşır. Şu anda önerilen etiketli bir halka açık derleme yoktur; açıkça desteklendiği belirtilen sonraki kaynak sürümünü bekleyin. GitHub’ın otomatik kaynak arşivleri macOS yükleyicisi değildir.

## Temel özellikler

- Sınırlı, gözlenen şema filtreleriyle seçilen aday Codex satırlarını tek yerde
  gösterir; bu filtreler kullanıcı sahipliğini veya eksiksiz kök sınıflamasını
  kanıtlamaz.
- Bekleyen kullanıcı girdisini, blokajı ve görülmemiş sonuçları ayırır.
- Sessizliği “çalışıyor” ya da “terk edilmiş” diye yorumlamaz.
- Bir işi checkpoint ve tek sonraki adımla park etmeyi sağlar.
- Kanıt yetersizse görev sıralamaktan açıkça kaçınır.
- Obsolete ve terk edilmiş gibi yüksek etkili kararları yalnız kullanıcı onayıyla uygular ve geri alınabilir tutar.
- Codex Desktop’ın seçilen görevi gözlenen `codex://threads/<id>` rotasıyla
  açmasını ister; davranış kurulu Codex sürümüne bağlıdır.
- Dashboard, editör, durum menüsü ve Wingman arayüzünü TR/EN arasında anında
  değiştirir; yerel seçimi sonraki açılış için hatırlar.
- İstenirse prompting, harness, yarım kalan işler ve token inceleme adayları
  için ayrı bir Codex CLI Wingman turu başlatır.
- Dashboard ağ isteği yapmaz ve arka planda ajan çağrısı başlatmaz. AiWingman
  Codex kaydı, şeması veya rollout dosyası yazmaz; ancak SQLite WAL eşgüdümü
  `~/.codex` altında yardımcı bir `state_5.sqlite-shm` ya da
  `goals_1.sqlite-shm` dosyası oluşturabilir veya güncelleyebilir. Ayrıntılı
  sınır [PRIVACY.md](PRIVACY.md) dosyasındadır; bu dosya SQLite/Codex yaşam
  döngüsüne göre kalıcı olabilir.

## Gereksinimler

- Paket macOS 13 dağıtım hedefi bildirir. Mevcut otomatik derleme ve testler daha yeni macOS sürümlerinde çalıştı; gerçek bir macOS 13 açılış veya çalışma zamanı sonucu henüz raporlanmadı.
- Aynı macOS hesabında daha önce kullanılmış Codex Desktop veya Codex CLI.
- Kaynaktan derleme için güncel Xcode ya da uyumlu Swift araç zinciri.
- Yalnız isteğe bağlı uzak Wingman eleştirisi için ayrıca uyumlu, ayrı kurulmuş
  ve giriş yapılmış Codex CLI; dashboard için gerekmez.

Uzak çağrıdan önce AiWingman, stdin üzerinden vermeyi amaçladığı kullanıcı-
türevi JSON paketinin tamamını incelemeye sunar ve her çağrı için tek kullanımlık
açık onay ister. Paket, kaynakta bulunan ve görev verisi içermeyen sabit inceleme
talimatı ile çıktı şemasıyla birlikte işlenir.
Ham prompt örnekleri, prompt-türevi temalar ve yerel metin sinyalleri tek bir
ayrı seçenekle ve varsayılanı kapalı olarak paylaşılır. Seçenek kapalıyken
görevden türetilen serbest metin yalnız temizlenmiş başlıklarla sınırlıdır;
prompt örnekleri, prompt-türevi temalar, yerel inceleme sinyalleri ve sonraki
adım metinleri pakete alınmaz. Paket yine zaman damgalarını ve etkinlik kesimini,
durum/enum alanlarını, boolean değerleri, sayımları, sayısal ölçümleri,
şema/dil meta verisini ve sabit yöntem-sınırı metnini taşır. AiWingman, agent
araçlarının workspace’e yazmasını engellemesi amaçlanan Codex CLI salt-okunur
sandbox modunu ister. Bu, OS düzeyinde izolasyon veya sıfır dosya yazma garantisi
değildir ve child process’in başka yerel dosyaları okuyamayacağını kanıtlamaz. Bu nedenle önizlenen paket, CLI’ın teknik
olarak erişebileceği tek bağlam gibi değerlendirilmemelidir.

Wingman penceresini açmak Codex CLI'yi çalıştırmaz. Ayrı ve açık **Codex CLI'yi
denetle** eylemi sürümü, komut uyumunu ve oturum durumunu ajan turu başlatmadan
ve görev paketi göndermeden denetler. Bu denetim, kayıtlı CLI kimlik doğrulama
dosyasının geçici özel ve opak bir kopyasını kullanır; aynı belgelenmiş temizleme
sınırı geçerlidir.

Desteklenen yeni exact tag yayımlanana kadar kaynaktan kurulum talimatı yoktur.
Hareketli bir dalı veya `v1.2.0-beta.2` etiketini kullanmayın; GitHub kaynak
arşivini “çift tıkla kurulum” paketi olarak değerlendirmeyin.

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

Tanılama komutu sabit şemalı toplu uyumluluk sayaçları üretir; görev metni,
ham görev kimliği, dosya yolu veya checkpoint içermez. Araştırma dışa aktarımı
ham Codex görev kimliği veya insan-yazımı görev metni içermez; tuzlanmış görev
takma adı, zaman damgası, sabit olay türü ve koşul içerir.

Kaynaktan paketlediğiniz uygulama Dock’ta görünmez; AiWingman bir menü
çubuğu uygulamasıdır. Açtıktan sonra menü çubuğundaki radar simgesini kullanın
veya paneli `⌘⇧K` ile çağırın. Bu yerel ad-hoc paket, halka açık imzalı sürüm
yerine geçmez.

Bağlantının nasıl çalıştığı için [Codex entegrasyonu](docs/CODEX_INTEGRATION.md), veri sınırları için [PRIVACY.md](PRIVACY.md), katkı için [CONTRIBUTING.md](CONTRIBUTING.md), araştırmada atıf için [CITATION.cff](CITATION.cff) dosyasına bakın.

Yazılım kaynağı, testler, betikler ve çalıştırılabilir araçlar
[MIT Lisansı](LICENSE) altındadır. Makale, üretilen bilimsel çıktılar ve belirtilen
çalıştırılamaz araştırma paketi CC BY 4.0 altındadır; dosya düzeyindeki kesin
harita [paper/LICENSE_STATUS.md](paper/LICENSE_STATUS.md) dosyasındadır.

AiWingman bağımsız ve resmi olmayan bir topluluk projesidir; OpenAI tarafından yayımlanan veya desteklenen resmi bir ürün değildir. Uzak Wingman çağrısı kullanıcının mevcut Codex CLI hesabını kullanır ve o hesabın plan/kotasından tüketebilir; AiWingman’ın kendisi ücretsizdir.
