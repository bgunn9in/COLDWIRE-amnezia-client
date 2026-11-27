# COLDWIRE Amnezia VPN

[English](README.md)

COLDWIRE Amnezia VPN — форк AmneziaVPN. Перед подключением по AmneziaWG 3.1 приложение запрашивает SPA-допуск на входном узле COLDWIRE. Для подключения нужен `.vpn`, который выдал или конвертировал администратор реле.

- [Скачать для Mac с Apple Silicon](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/latest/download/COLDWIRE-macOS.pkg).
- [Скачать для Windows x64 или Android ARM64](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/latest). Выберите APK для Android 9/10 или Android 11 и новее.
- [Установить приложение и подключиться](docs/spa.ru.md).
- [Развернуть реле или управлять устройствами](https://github.com/bgunn9in/coldwire).

В предварительной сборке появился отчёт о соединении. На Windows и macOS допуск SPA теперь продлевает VPN-служба. В примечаниях к выпуску указано, какие проверки Android 9 и сна macOS ещё предстоят. [Скачать предварительную сборку](https://github.com/bgunn9in/COLDWIRE-amnezia-client/releases/tag/coldwire-preview-b1377ae987b6)

GitHub Actions собирает стабильные установщики из ветки `feature/spa-admission`. В релизе есть контрольные суммы SHA-256 и ссылка на сборку. Приложение распространяется по [лицензии исходного проекта](LICENSE). [AmneziaVPN](https://github.com/amnezia-vpn/amnezia-client)
