# AiWingman’i macOS’e Kurma

## Sürüm durumu

**GÜVENLİK BEKLEMESİ:** `v1.2.0-beta.2` ve onunla eşleşen ana dal görüntüsü
geçersiz kılındı. Derlemeyin veya kullanmayın. Şu anda desteklenen public tag ya
da binary yoktur. [Beta2 release sayfası](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.2)
aynı uyarıyı taşır.

## Gereksinimler

- macOS 13 veya üzeri.
- Aynı macOS hesabında daha önce kullanılmış Codex Desktop veya Codex CLI.
- Seçilen görevi yerel deep link ile açmak için Codex Desktop.
- AiWingman hesabı, ayrı API anahtarı isteme/saklama, OAuth veya eklenti gerekmez.
- Yalnız isteğe bağlı uzak Wingman eleştirisi için uyumlu, ayrı kurulmuş ve
  giriş yapılmış Codex CLI gerekir; dashboard onsuz çalışır. Uzak çağrı,
  kullanıcının mevcut Codex planından veya kotasından tüketebilir.

## Kurulum beklemede

`v1.2.0-beta.2` veya hareketli/ana daldan derlemeyin. Exact-tag kaynak
talimatları yalnız güçlendirilmiş aday gizlilik ve sürüm kapılarını geçtikten
sonra yayımlanacaktır. GitHub kaynak arşivleri yükleyici değildir.

## Gelecekteki imzalı indirmeler

Aşağıdaki bölümler yalnız ilerideki bir release açıkça Developer ID ile imzalı
ve Apple tarafından noterlenmiş uygulama içerirse geçerlidir. Güncel beta içermez.

## İndirmeyi doğrulama

DMG ya da ZIP ile birlikte `SHA256SUMS` dosyasını da indirin. Terminal'de indirdiğiniz dosyaya uygun komutu çalıştırın:

```sh
shasum -a 256 "<indirilen-dosya>.dmg"
shasum -a 256 "<indirilen-dosya>.zip"
```

Çıktıdaki özet, `SHA256SUMS` içindeki ilgili satırla birebir aynı olmalıdır. Release sayfasında ayrıca `RELEASE-MANIFEST.txt` ve temiz-makine kabul JSON'u bulunmalıdır. Özet farklıysa, beklenen dosya yoksa veya sürüm imzalı ve noterlenmiş olduğunu açıkça söylemiyorsa durun.

## DMG ile kurulum (önerilen)

1. Doğruladığınız `.dmg` dosyasını açın.
2. **AiWingman** uygulamasını disk imajındaki **Applications** bağlantısına sürükleyin.
3. Finder'da disk imajını çıkarın.
4. `/Applications/AiWingman.app` dosyasını açın.

macOS'in olağan Gatekeeper denetimini yapabilmesi için tarayıcı karantinasını koruyun. Uygulamayı disk imajının içinden çalıştırmayın.

## ZIP ile kurulum (alternatif)

1. Doğruladığınız `.zip` dosyasını açın.
2. **AiWingman.app** dosyasını `/Applications` klasörüne taşıyın.
3. Uygulamayı Downloads içinden değil Applications içinden açın.

ZIP, aynı imzalı ve noterlenmiş uygulamanın alternatif taşıma biçimidir. Önerilen indirme DMG'dir.

## İlk çalıştırma

AiWingman bir menü çubuğu uygulamasıdır (`LSUIElement`); Dock'ta görünmez. Açtıktan sonra menü çubuğundaki radar simgesine bakın veya paneli göstermek için `⌘⇧K` tuşlarına basın. İlk göreve dönme işleminde macOS, Codex Desktop'ın açılmasını onaylamanızı isteyebilir.

Arama başlığındaki kompakt **TR/EN** denetimi dashboard, editör, durum menüsü ve
Wingman arayüzünün dilini anında değiştirir. AiWingman seçimi sonraki açılış
için yerel olarak hatırlar.

AiWingman uyumlu yerel Codex durumu bulamazsa nötr biçimde durur. Codex verisi oluşturmaz, onarmaz, yüklemez veya değiştirmez.

**Bir Wingman Çağır** isteğe bağlı bir uzak eleştiri başlatabilir. AiWingman’in
Codex CLI’a stdin üzerinden vermeyi amaçladığı tam JSON paketini önce
gösterir ve her çağrı için tek kullanımlık açık onay ister; arka planda çağrı
yapılmaz. Ham prompt örnekleri varsayılan olarak dışarıdadır. AiWingman CLI’ın
salt-okunur sandbox modunu ister; bu mod agent araçlarının workspace’e yazmasını
engellemek üzere tasarlanmıştır, ancak OS düzeyinde izolasyon veya sıfır dosya
yazma garantisi değildir. Child process’in başka yerel dosyaları okuyamayacağını
da garanti etmez. Dolayısıyla önizleme, paketin CLI’ın teknik olarak
erişebileceği tek bağlam olduğu iddiası değildir. Onay vermeden önce
[PRIVACY.md](PRIVACY.md) dosyasını okuyun.

## İzinler ve gizlilik

AiWingman mevcut kullanıcının yerel Codex durumunu okur; kendi süreklilik verisini eski sürümlerle uyum için `~/Library/Application Support/Activity Radar` altında saklar. Tam Disk Erişimi, Erişilebilirlik, Ekran Kaydı ve yönetici yetkisi gerekmez. Dashboard ağ bağlantısı istemez; isteğe bağlı uzak eleştiri yalnız onaydan sonra ayrı kurulmuş ve giriş yapılmış Codex CLI’ı kullanır. Beklenmedik geniş bir izin vermeyin; durumu [SECURITY.md](SECURITY.md) üzerinden bildirin.

Tam veri sınırı için [PRIVACY.md](PRIVACY.md) dosyasına bakın. Bir issue'ya `~/.codex`, Codex veritabanı, rollout dosyası veya gerçek görev ekran görüntüsü eklemeyin.

## Güncelleme

1. Durum menüsünden AiWingman’i kapatın.
2. Yeni sürümü yukarıdaki adımlarla indirin ve doğrulayın.
3. Yeni uygulamayı Applications'a sürükleyin; Finder sorarsa **Değiştir** seçeneğini kullanın.
4. Yeni kopyayı açıp sürümü **AiWingman Hakkında…** ekranında doğrulayın.

Uygulamayı değiştirmek, AiWingman’in ayrı yerel süreklilik verisini korur. Eski `ActivityRadar` bundle kimlikleri ve veri yolu uyumluluk için bilinçli olarak korunur. Bir sürüm geçişi `~/.codex` içine yazmamalı veya orayı değiştirmemelidir.

## Kaldırma

1. AiWingman’i kapatın.
2. `/Applications/AiWingman.app` dosyasını Çöp'e taşıyın.
3. İsteğe bağlı olarak yalnız AiWingman’e ait eski uyumluluk yolu `~/Library/Application Support/Activity Radar` klasörünü ve kullandığınız dağıtıma ait tercih dosyasını silin: imzalı public paket için `~/Library/Preferences/io.github.mehmetsolakedu.ActivityRadar.plist`, yerel paket için `~/Library/Preferences/local.mehmet.activityradar.plist`. İki dağıtımı da kullandıysanız iki kopyayı da kapattıktan sonra iki tercih dosyasını silebilirsiniz.

`~/.codex` klasörünü silmeyin veya düzenlemeyin; bu klasör AiWingman’e değil Codex’e aittir.

## Güvenli sorun giderme

- Applications içindeki kopyayı açtığınızı doğrulayın; menü çubuğu simgesine bakın veya `⌘⇧K` tuşlarına basın.
- Codex'in aynı macOS hesabında daha önce kullanıldığını doğrulayın.
- Yalnız uzak eleştiri kullanılamıyorsa `codex --version` ve `codex login status`
  komutlarını doğrulayın; ardından Wingman ekranındaki **Codex CLI'yi yeniden
  denetle** düğmesini kullanın. Dashboard CLI olmadan çalışmaya devam eder.
- İndirme özetini yeniden karşılaştırın ve release notlarındaki bilinen sınırlamaları okuyun.
- Issue formu isterse yalnız içeriksiz tanılamayı veya kopyalanan destek bilgisini paylaşın.

Doğrulanmamış bir indirmeyi çalıştırmak için Gatekeeper'ı kapatmayın, `xattr -dr` ile karantinayı kaldırmayın, `sudo` kullanmayın, uygulamayı yeniden imzalamayın veya özel Codex dosyalarını yüklemeyin. macOS desteklenen bir sürümü reddederse durun; yalnız public release etiketi ve içeriksiz hatayı bildirin.

## Kaynaktan derleme

Kaynak derlemeleri, onları üreten makinede geliştirme içindir ve varsayılan olarak ad-hoc imza kullanır. [README.md](README.md) içindeki exact-tag adımlarını izleyin; yerel ad-hoc derleme desteklenen public binary sürüm değildir.
