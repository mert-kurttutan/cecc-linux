# Destek Bilgileri

Excalibur Control Center veya `casper-wmi` ile ilgili bir sorun bildirirken
terminalde şu komutu çalıştırın ve çıktının tamamını sorun bildiriminize ekleyin:

```sh
excalibur-control-center-cli doctor
```

Rapor; uygulama ve çekirdek sürümlerini, DMI kimliğini, CPU bilgilerini, Casper
WMI aygıtlarını, sürücü durumunu ve algılanan LED/fan arayüzlerini içerir.

Sürücü görünmüyorsa veya yüklenemediyse filtrelenmiş çekirdek mesajlarını da
toplayın:

```sh
sudo excalibur-control-center-cli doctor --include-dmesg
```

Paylaşmadan önce çıktıyı inceleyin. İsteğe bağlı çekirdek mesajları başka sistem
bilgileri içerebilir. Paylaşmak istemediğiniz bilgileri gizleyebilirsiniz; ancak
mümkünse DMI `sys_vendor` ve `product_name` alanlarını olduğu gibi bırakın. Bu
alanlar sürücüde bilgisayar modelini eşleştirmek için kullanılır.
