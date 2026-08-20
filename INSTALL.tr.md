# Activity Radar’ı macOS’e Kurma

## Sürüm durumu

[`v1.2.0-beta.1`](https://github.com/mehmetsolakedu/activity-radar/releases/tag/v1.2.0-beta.1), kurulabilir uygulama içermeyen tarihsel bir kaynak-öncelikli betadır. Desteklenen bir binary sürüm; Developer ID ile imzalandığını ve Apple tarafından noterlenmiş olduğunu açıkça söylemeli, ayrıca DMG, ZIP, `SHA256SUMS`, `RELEASE-MANIFEST.txt` ve temiz-makine kabul kaydı içermelidir. GitHub'ın otomatik “Source code” arşivlerini macOS yükleyicisi saymayın.

## Gereksinimler

- macOS 13 veya üzeri.
- Aynı macOS hesabında daha önce kullanılmış Codex Desktop veya Codex CLI.
- Seçilen görevi yerel deep link ile açmak için Codex Desktop.
- Activity Radar hesabı, API anahtarı, OAuth veya eklenti gerekmez.

## İndirmeyi doğrulama

DMG ya da ZIP ile birlikte `SHA256SUMS` dosyasını da indirin. Terminal'de indirdiğiniz dosyaya uygun komutu çalıştırın:

```sh
shasum -a 256 "Activity-Radar-<sürüm>-macOS-universal2.dmg"
shasum -a 256 "Activity-Radar-<sürüm>-macOS-universal2.zip"
```

Çıktıdaki özet, `SHA256SUMS` içindeki ilgili satırla birebir aynı olmalıdır. Release sayfasında ayrıca `RELEASE-MANIFEST.txt` ve temiz-makine kabul JSON'u bulunmalıdır. Özet farklıysa, beklenen dosya yoksa veya sürüm imzalı ve noterlenmiş olduğunu açıkça söylemiyorsa durun.

## DMG ile kurulum (önerilen)

1. Doğruladığınız `.dmg` dosyasını açın.
2. **Activity Radar** uygulamasını disk imajındaki **Applications** bağlantısına sürükleyin.
3. Finder'da **Activity Radar** disk imajını çıkarın.
4. `/Applications/Activity Radar.app` dosyasını açın.

macOS'in olağan Gatekeeper denetimini yapabilmesi için tarayıcı karantinasını koruyun. Uygulamayı disk imajının içinden çalıştırmayın.

## ZIP ile kurulum (alternatif)

1. Doğruladığınız `.zip` dosyasını açın.
2. **Activity Radar.app** dosyasını `/Applications` klasörüne taşıyın.
3. Uygulamayı Downloads içinden değil Applications içinden açın.

ZIP, aynı imzalı ve noterlenmiş uygulamanın alternatif taşıma biçimidir. Önerilen indirme DMG'dir.

## İlk çalıştırma

Activity Radar bir menü çubuğu uygulamasıdır (`LSUIElement`); Dock'ta görünmez. Açtıktan sonra menü çubuğundaki radar simgesine bakın veya paneli göstermek için `⌘⇧K` tuşlarına basın. İlk göreve dönme işleminde macOS, Codex Desktop'ın açılmasını onaylamanızı isteyebilir.

Activity Radar uyumlu yerel Codex durumu bulamazsa nötr biçimde durur. Codex verisi oluşturmaz, onarmaz, yüklemez veya değiştirmez.

## İzinler ve gizlilik

Activity Radar mevcut kullanıcının yerel Codex durumunu okur; kendi süreklilik verisini `~/Library/Application Support/Activity Radar` altında saklar. Tam Disk Erişimi, Erişilebilirlik, Ekran Kaydı, yönetici yetkisi ve ağ izni gerekmez. Beklenmedik geniş bir izin vermeyin; durumu [SECURITY.md](SECURITY.md) üzerinden bildirin.

Tam veri sınırı için [PRIVACY.md](PRIVACY.md) dosyasına bakın. Bir issue'ya `~/.codex`, Codex veritabanı, rollout dosyası veya gerçek görev ekran görüntüsü eklemeyin.

## Güncelleme

1. Durum menüsünden Activity Radar'ı kapatın.
2. Yeni sürümü yukarıdaki adımlarla indirin ve doğrulayın.
3. Yeni uygulamayı Applications'a sürükleyin; Finder sorarsa **Değiştir** seçeneğini kullanın.
4. Yeni kopyayı açıp sürümü **Activity Radar Hakkında…** ekranında doğrulayın.

Uygulamayı değiştirmek, Activity Radar'ın ayrı yerel süreklilik verisini korur. Bir sürüm geçişi `~/.codex` içine yazmamalı veya orayı değiştirmemelidir.

## Kaldırma

1. Activity Radar'ı kapatın.
2. `/Applications/Activity Radar.app` dosyasını Çöp'e taşıyın.
3. İsteğe bağlı olarak yalnız Activity Radar'a ait `~/Library/Application Support/Activity Radar` klasörünü ve `~/Library/Preferences/io.github.mehmetsolakedu.ActivityRadar.plist` tercih dosyasını silin.

`~/.codex` klasörünü silmeyin veya düzenlemeyin; bu klasör Activity Radar'a değil Codex'e aittir.

## Güvenli sorun giderme

- Applications içindeki kopyayı açtığınızı doğrulayın; menü çubuğu simgesine bakın veya `⌘⇧K` tuşlarına basın.
- Codex'in aynı macOS hesabında daha önce kullanıldığını doğrulayın.
- İndirme özetini yeniden karşılaştırın ve release notlarındaki bilinen sınırlamaları okuyun.
- Issue formu isterse yalnız içeriksiz tanılamayı veya kopyalanan destek bilgisini paylaşın.

Doğrulanmamış bir indirmeyi çalıştırmak için Gatekeeper'ı kapatmayın, `xattr -dr` ile karantinayı kaldırmayın, `sudo` kullanmayın, uygulamayı yeniden imzalamayın veya özel Codex dosyalarını yüklemeyin. macOS desteklenen bir sürümü reddederse durun; yalnız public release etiketi ve içeriksiz hatayı bildirin.

## Kaynaktan derleme

Kaynak derlemeleri, onları üreten makinede geliştirme içindir ve varsayılan olarak ad-hoc imza kullanır. [README.md](README.md) içindeki exact-tag adımlarını izleyin; yerel ad-hoc derleme desteklenen public binary sürüm değildir.
