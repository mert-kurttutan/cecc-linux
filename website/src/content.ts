export type Page =
  | 'home'
  | 'install'
  | 'getting-started'
  | 'gui-cli'
  | 'driver'
  | 'troubleshooting'
  | 'about'
  | 'development'

export const locales = ['en', 'tr'] as const
export type Locale = (typeof locales)[number]

export type NavItem = {
  label: string
  href: string
  page: Page
}

export type LinkItem = {
  label: string
  href: string
}

export type CardItem = {
  title: string
  body: string
  command?: string
  href?: string
}

export type DocLink = Omit<CardItem, 'command' | 'href'> & {
  href: string
}

export type SiteContent = {
  lang: Locale
  languageSwitchLabel: string
  sponsorLabel: string
  commandCopy: {
    copy: string
    copied: string
    failed: string
    copyAria: string
    copiedAria: string
    failedAria: string
  }
  navItems: NavItem[]
  home: {
    eyebrow: string
    title: string
    intro: string
    primaryCta: string
    secondaryCta: string
    heroAlt: string
    valueSections: CardItem[]
    terminalEyebrow: string
    terminalTitle: string
    terminalBody: string
    terminalCommand: string
    summary: { label: string; value: string }[]
    docsEyebrow: string
    docsTitle: string
    openLabel: string
    projectEyebrow: string
    projectTitle: string
  }
  install: {
    title: string
    intro: string
    options: CardItem[]
  }
  gettingStarted: {
    title: string
    intro: string
    steps: CardItem[]
  }
  guiCli: {
    title: string
    intro: string
    cards: CardItem[]
  }
  driver: {
    title: string
    intro: string
    cards: CardItem[]
  }
  troubleshooting: {
    title: string
    intro: string
    command: string
    items: string[]
  }
  about: {
    title: string
    intro: string
    projectTitle: string
    items: string[]
    creditsTitle: string
    creditItems: LinkItem[]
    licenseTitle: string
    licenseBody: string
  }
  development: {
    title: string
    intro: string
    commands: CardItem[]
  }
  docLinks: DocLink[]
  projectLinks: LinkItem[]
}

const pagePaths: Record<Locale, Record<Page, string>> = {
  en: {
    home: '/',
    install: '/install',
    'getting-started': '/getting-started',
    'gui-cli': '/gui-cli',
    driver: '/driver',
    troubleshooting: '/troubleshooting',
    about: '/about',
    development: '/development',
  },
  tr: {
    home: '/',
    install: '/kurulum',
    'getting-started': '/baslangic',
    'gui-cli': '/gui-cli',
    driver: '/surucu',
    troubleshooting: '/sorun-giderme',
    about: '/hakkinda',
    development: '/gelistirme',
  },
}

export const routePaths = {
  en: {
    home: '/en',
    install: '/en/install',
    'getting-started': '/en/getting-started',
    'gui-cli': '/en/gui-cli',
    driver: '/en/driver',
    troubleshooting: '/en/troubleshooting',
    about: '/en/about',
    development: '/en/development',
  },
  tr: {
    home: '/tr',
    install: '/tr/kurulum',
    'getting-started': '/tr/baslangic',
    'gui-cli': '/tr/gui-cli',
    driver: '/tr/surucu',
    troubleshooting: '/tr/sorun-giderme',
    about: '/tr/hakkinda',
    development: '/tr/gelistirme',
  },
} satisfies Record<Locale, Record<Page, string>>

export const prerenderPaths = Object.values(routePaths).flatMap((paths) => Object.values(paths))

const terminalCommand =
  'excalibur-control-center-cli status\nexcalibur-control-center-cli gpu get\nexcalibur-control-center-cli keyboard get all\nexcalibur-control-center-cli doctor'

const installCommands = {
  fullStack:
    'curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | sudo bash',
  debian:
    'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center_0.1.33_amd64.deb\nsudo apt install ./excalibur-control-center_0.1.33_amd64.deb',
  fedora:
    'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center-0.1.33-1.x86_64.rpm\nsudo dnf install ./excalibur-control-center-0.1.33-1.x86_64.rpm',
}

const workflowCommands = {
  gui: 'excalibur-control-center-gui',
  cli: 'excalibur-control-center-cli status\nexcalibur-control-center-cli gpu get\nexcalibur-control-center-cli keyboard get all',
  doctor: 'excalibur-control-center-cli doctor\nexcalibur-control-center-cli doctor --include-dmesg',
}

const driverCommands = {
  kernel: 'lsmod | grep casper_wmi\nls /sys/module/casper_wmi',
  subsystems: 'cat /sys/firmware/acpi/platform_profile\nls /sys/class/hwmon',
  reload: 'nix develop\nnu ./scripts/reload.nu',
}

const devCommands = {
  rust:
    'cd excalibur-control-center\ncargo build\ncargo run -p excalibur-control-center-cli -- doctor\ncargo run -p excalibur-control-center-gui',
  driver: 'nix develop\nnu ./scripts/reload.nu',
  website: 'cd website\nnpm install\nnpm run dev\nnpm run check\nnpm run build',
}

export const siteContent: Record<Locale, SiteContent> = {
  en: {
    lang: 'en',
    languageSwitchLabel: 'Türkçe',
    sponsorLabel: 'Sponsor development',
    commandCopy: {
      copy: 'Copy',
      copied: 'Copied',
      failed: 'Failed',
      copyAria: 'Copy command',
      copiedAria: 'Command copied',
      failedAria: 'Copy failed',
    },
    navItems: [
      { label: 'Home', href: '/', page: 'home' },
      { label: 'Install', href: '/install', page: 'install' },
      { label: 'Getting Started', href: '/getting-started', page: 'getting-started' },
      { label: 'GUI & CLI', href: '/gui-cli', page: 'gui-cli' },
      { label: 'Driver', href: '/driver', page: 'driver' },
      { label: 'Troubleshooting', href: '/troubleshooting', page: 'troubleshooting' },
      { label: 'About', href: '/about', page: 'about' },
      { label: 'Development', href: '/development', page: 'development' },
    ],
    home: {
      eyebrow: 'Linux controls for Casper Excalibur laptops',
      title: 'Excalibur Control Center for Linux.',
      intro:
        'cecc-linux ports Excalibur Control Center behavior to Linux with a GUI, CLI, packages, and driver support.',
      primaryCta: 'Install',
      secondaryCta: 'Get started',
      heroAlt: 'Excalibur Control Center interface preview',
      valueSections: [
        { title: 'Linux port', body: 'Excalibur Control Center behavior for Linux.' },
        { title: 'Controls', body: 'Profiles, display mode, RGB, and telemetry.' },
        { title: 'Packages', body: 'Install the app, or use the full driver stack.' },
      ],
      terminalEyebrow: 'Works from the terminal too',
      terminalTitle: 'Scriptable controls.',
      terminalBody: 'Use the CLI for status checks, lighting reads, GPU mode, and support reports.',
      terminalCommand,
      summary: [
        { label: 'Port', value: 'Control Center behavior on Linux' },
        { label: 'Controls', value: 'Profiles, display, RGB, telemetry' },
        { label: 'Install', value: 'Packages or driver stack' },
      ],
      docsEyebrow: 'Documentation',
      docsTitle: 'Open the guide that matches your task.',
      openLabel: 'Open',
      projectEyebrow: 'Project',
      projectTitle: 'Follow releases or report model-specific issues on GitHub.',
    },
    install: {
      title: 'Install',
      intro:
        'Install the package or the full driver stack. All options install the GUI, CLI, udev rules, and permission helper. Choose the full stack installer if you also need the casper-wmi DKMS driver.',
      options: [
        {
          title: 'Full stack',
          body: 'App, permission rules, and DKMS driver.',
          command: installCommands.fullStack,
        },
        {
          title: 'Debian / Ubuntu',
          body: 'GUI, CLI, udev rules, and permission helper.',
          command: installCommands.debian,
        },
        {
          title: 'Fedora / RPM',
          body: 'GUI, CLI, udev rules, and permission helper.',
          command: installCommands.fedora,
        },
      ],
    },
    gettingStarted: {
      title: 'Getting Started',
      intro:
        'Verify access before changing hardware state. These are the first checks to run after installing the package or the full stack.',
      steps: [
        {
          title: 'Join the group',
          body: 'Package installs create the excalibur group for non-root hardware access.',
          command: 'sudo usermod -aG excalibur "$USER"',
        },
        {
          title: 'Start the GUI',
          body: 'Log out and back in after changing groups, then launch the desktop app.',
          command: 'excalibur-control-center-gui',
        },
        {
          title: 'Check status',
          body: 'Use the CLI to confirm the driver and exposed controls are visible.',
          command: 'excalibur-control-center-cli status',
        },
      ],
    },
    guiCli: {
      title: 'GUI & CLI',
      intro: 'Use the GUI for daily control and the CLI for repeatable checks.',
      cards: [
        {
          title: 'GUI',
          body: 'Desktop controls for profiles, display mode, lighting, telemetry, and diagnostics.',
          command: workflowCommands.gui,
        },
        {
          title: 'CLI',
          body: 'Scriptable access to status, GPU mode, keyboard zones, and support reports.',
          command: workflowCommands.cli,
        },
        {
          title: 'Support report',
          body: 'Collect read-only diagnostics when checking a new model or reporting a bug.',
          command: workflowCommands.doctor,
        },
      ],
    },
    driver: {
      title: 'Driver',
      intro:
        'casper-wmi exposes Excalibur controls through Linux interfaces. It is the kernel-side piece for fan telemetry, keyboard LEDs, GPU/display mode, and platform profiles.',
      cards: [
        {
          title: 'Kernel module',
          body: 'casper-wmi is an out-of-tree driver for Casper Excalibur WMI controls.',
          command: driverCommands.kernel,
        },
        {
          title: 'Linux subsystems',
          body: 'Controls are exposed through sysfs, LEDs, hwmon, and platform profile interfaces.',
          command: driverCommands.subsystems,
        },
        {
          title: 'Development reload',
          body: 'Use the repo reload script when testing local driver changes.',
          command: driverCommands.reload,
        },
      ],
    },
    troubleshooting: {
      title: 'Troubleshooting',
      intro:
        'Start with a support report. The doctor command collects kernel, DMI, WMI, driver, LED, and hwmon probes for bug reports without changing hardware state.',
      command: workflowCommands.doctor,
      items: [
        'Run doctor first; it is read-only by default.',
        'Use --include-dmesg when reporting driver or WMI problems.',
        'If permissions fail, verify group membership and log in again.',
        'If controls are missing, check that casper-wmi is loaded.',
      ],
    },
    about: {
      title: 'About',
      intro: 'Project information and credits from the Excalibur Control Center desktop app.',
      projectTitle: 'Project',
      items: [
        'Linux control center for Casper Excalibur laptops.',
        'Origin: Linux port of Casper Excalibur Control Center behavior.',
        'Features: keyboard RGB zones, brightness control, GPU mode control, and driver-backed hardware state.',
        "Driver: casper-wmi, based on Mustafa Eksi's Casper WMI work.",
      ],
      creditsTitle: 'Credits',
      creditItems: [
        { label: 'App author: Mert Kurttutan', href: 'https://github.com/mert-kurttutan' },
        { label: 'Author for original driver code: Mustafa Eksi', href: 'https://github.com/Mustafa-eksi' },
        { label: 'Source code: cecc-linux', href: 'https://github.com/mert-kurttutan/cecc-linux' },
      ],
      licenseTitle: 'License',
      licenseBody:
        'The userspace application is MIT licensed. The kernel driver code is GPL-2.0-or-later, as marked in the driver source.',
    },
    development: {
      title: 'Development',
      intro:
        'Workflow commands for app, driver, and website changes. Use these when working on the Rust workspace, reloading the local driver, or changing this documentation site.',
      commands: [
        { title: 'Rust workspace', body: '', command: devCommands.rust },
        { title: 'Driver reload', body: '', command: devCommands.driver },
        { title: 'Website', body: '', command: devCommands.website },
      ],
    },
    docLinks: [
      { title: 'Install', body: 'Package, full installer, and driver-stack paths.', href: '/install' },
      { title: 'Getting Started', body: 'First-run checks after installation.', href: '/getting-started' },
      { title: 'GUI & CLI', body: 'Daily controls and repeatable terminal commands.', href: '/gui-cli' },
      { title: 'Driver', body: 'casper-wmi and Linux interface notes.', href: '/driver' },
      { title: 'Troubleshooting', body: 'Support report commands and first checks.', href: '/troubleshooting' },
      { title: 'About', body: 'Project scope, credits, source, and license notes.', href: '/about' },
      { title: 'Development', body: 'Rust, driver reload, and website workflow.', href: '/development' },
    ],
    projectLinks: [
      { label: 'GitHub repository', href: 'https://github.com/mert-kurttutan/cecc-linux' },
      { label: 'Releases', href: 'https://github.com/mert-kurttutan/cecc-linux/releases' },
      { label: 'Report an issue', href: 'https://github.com/mert-kurttutan/cecc-linux/issues' },
    ],
  },
  tr: {
    lang: 'tr',
    languageSwitchLabel: 'English',
    sponsorLabel: 'Projeye sponsor ol',
    commandCopy: {
      copy: 'Kopyala',
      copied: 'Kopyalandı',
      failed: 'Başarısız',
      copyAria: 'Komutu kopyala',
      copiedAria: 'Komut kopyalandı',
      failedAria: 'Kopyalama başarısız',
    },
    navItems: [
      { label: 'Ana sayfa', href: '/', page: 'home' },
      { label: 'Kurulum', href: '/install', page: 'install' },
      { label: 'Başlangıç', href: '/getting-started', page: 'getting-started' },
      { label: 'GUI ve CLI', href: '/gui-cli', page: 'gui-cli' },
      { label: 'Sürücü', href: '/driver', page: 'driver' },
      { label: 'Sorun Giderme', href: '/troubleshooting', page: 'troubleshooting' },
      { label: 'Hakkında', href: '/about', page: 'about' },
      { label: 'Geliştirme', href: '/development', page: 'development' },
    ],
    home: {
      eyebrow: 'Casper Excalibur dizüstüler için Linux kontrolleri',
      title: 'Linux için Excalibur Control Center.',
      intro:
        'cecc-linux, Excalibur Control Center davranışını GUI, CLI, paketler ve sürücü desteğiyle Linux’a taşır.',
      primaryCta: 'Kur',
      secondaryCta: 'Başla',
      heroAlt: 'Excalibur Control Center arayüz önizlemesi',
      valueSections: [
        { title: 'Linux portu', body: 'Excalibur Control Center davranışı Linux’ta.' },
        { title: 'Kontroller', body: 'Profiller, ekran modu, RGB ve telemetri.' },
        { title: 'Paketler', body: 'Uygulamayı kurun veya tam sürücü yığınını kullanın.' },
      ],
      terminalEyebrow: 'Terminalden de çalışır',
      terminalTitle: 'Betiklenebilir kontroller.',
      terminalBody: 'Durum, aydınlatma, GPU modu ve destek raporları için CLI kullanın.',
      terminalCommand,
      summary: [
        { label: 'Port', value: 'Control Center davranışı Linux’ta' },
        { label: 'Kontroller', value: 'Profiller, ekran, RGB, telemetri' },
        { label: 'Kurulum', value: 'Paketler veya sürücü yığını' },
      ],
      docsEyebrow: 'Belgeler',
      docsTitle: 'İşinize uygun kılavuzu açın.',
      openLabel: 'Aç',
      projectEyebrow: 'Proje',
      projectTitle: 'Sürümleri takip edin veya modele özel sorunları GitHub’da bildirin.',
    },
    install: {
      title: 'Kurulum',
      intro:
        'Paketi veya tam sürücü yığınını kurun. Tüm seçenekler GUI, CLI, udev kuralları ve izin yardımcısını kurar. casper-wmi DKMS sürücüsü de gerekiyorsa tam yığın kurulumunu seçin.',
      options: [
        {
          title: 'Tam yığın',
          body: 'Uygulama, izin kuralları ve DKMS sürücüsü.',
          command: installCommands.fullStack,
        },
        {
          title: 'Debian / Ubuntu',
          body: 'GUI, CLI, udev kuralları ve izin yardımcısı.',
          command: installCommands.debian,
        },
        {
          title: 'Fedora / RPM',
          body: 'GUI, CLI, udev kuralları ve izin yardımcısı.',
          command: installCommands.fedora,
        },
      ],
    },
    gettingStarted: {
      title: 'Başlangıç',
      intro:
        'Donanım durumunu değiştirmeden önce erişimi doğrulayın. Paket veya tam yığın kurulumundan sonra ilk kontroller bunlardır.',
      steps: [
        {
          title: 'Gruba katılın',
          body: 'Paket kurulumları root olmadan donanım erişimi için excalibur grubunu oluşturur.',
          command: 'sudo usermod -aG excalibur "$USER"',
        },
        {
          title: 'GUI’yi başlatın',
          body: 'Grup değişikliğinden sonra oturumu kapatıp açın, ardından masaüstü uygulamasını çalıştırın.',
          command: 'excalibur-control-center-gui',
        },
        {
          title: 'Durumu kontrol edin',
          body: 'Sürücünün ve kontrollerin göründüğünü doğrulamak için CLI kullanın.',
          command: 'excalibur-control-center-cli status',
        },
      ],
    },
    guiCli: {
      title: 'GUI ve CLI',
      intro: 'Günlük kontrol için GUI’yi, tekrarlanabilir kontroller için CLI’yi kullanın.',
      cards: [
        {
          title: 'GUI',
          body: 'Profiller, ekran modu, aydınlatma, telemetri ve tanılama için masaüstü kontrolleri.',
          command: workflowCommands.gui,
        },
        {
          title: 'CLI',
          body: 'Durum, GPU modu, klavye bölgeleri ve destek raporları için betiklenebilir erişim.',
          command: workflowCommands.cli,
        },
        {
          title: 'Destek raporu',
          body: 'Yeni bir modeli kontrol ederken veya hata bildirirken salt okunur tanılama toplayın.',
          command: workflowCommands.doctor,
        },
      ],
    },
    driver: {
      title: 'Sürücü',
      intro:
        'casper-wmi, Excalibur kontrollerini Linux arayüzleri üzerinden sunar. Fan telemetrisi, klavye LED’leri, GPU/ekran modu ve platform profilleri için çekirdek tarafındaki parçadır.',
      cards: [
        {
          title: 'Çekirdek modülü',
          body: 'casper-wmi, Casper Excalibur WMI kontrolleri için ağaç dışı bir sürücüdür.',
          command: driverCommands.kernel,
        },
        {
          title: 'Linux alt sistemleri',
          body: 'Kontroller sysfs, LED, hwmon ve platform profile arayüzleri üzerinden sunulur.',
          command: driverCommands.subsystems,
        },
        {
          title: 'Geliştirme yeniden yüklemesi',
          body: 'Yerel sürücü değişikliklerini test ederken repo yeniden yükleme betiğini kullanın.',
          command: driverCommands.reload,
        },
      ],
    },
    troubleshooting: {
      title: 'Sorun Giderme',
      intro:
        'Destek raporuyla başlayın. doctor komutu hata raporları için çekirdek, DMI, WMI, sürücü, LED ve hwmon verilerini donanım durumunu değiştirmeden toplar.',
      command: workflowCommands.doctor,
      items: [
        'Önce doctor komutunu çalıştırın; varsayılan olarak salt okunurdur.',
        'Sürücü veya WMI sorunlarını bildirirken --include-dmesg kullanın.',
        'İzinler başarısız olursa grup üyeliğini doğrulayın ve yeniden oturum açın.',
        'Kontroller eksikse casper-wmi modülünün yüklü olduğunu kontrol edin.',
      ],
    },
    about: {
      title: 'Hakkında',
      intro: 'Excalibur Control Center masaüstü uygulamasındaki proje bilgileri ve katkılar.',
      projectTitle: 'Proje',
      items: [
        'Casper Excalibur dizüstüler için Linux kontrol merkezi.',
        'Köken: Excalibur Control Center davranışının Linux portu.',
        'Özellikler: klavye RGB bölgeleri, parlaklık kontrolü, GPU modu kontrolü ve sürücü destekli donanım durumu.',
        'Sürücü: Mustafa Eksi’nin Casper WMI çalışmasını temel alan casper-wmi.',
      ],
      creditsTitle: 'Katkılar',
      creditItems: [
        { label: 'Uygulama yazarı: Mert Kurttutan', href: 'https://github.com/mert-kurttutan' },
        { label: 'Özgün sürücü kodu yazarı: Mustafa Eksi', href: 'https://github.com/Mustafa-eksi' },
        { label: 'Kaynak kod: cecc-linux', href: 'https://github.com/mert-kurttutan/cecc-linux' },
      ],
      licenseTitle: 'Lisans',
      licenseBody:
        'Kullanıcı alanı uygulaması MIT lisanslıdır. Çekirdek sürücü kodu, sürücü kaynağında belirtildiği gibi GPL-2.0-or-later lisanslıdır.',
    },
    development: {
      title: 'Geliştirme',
      intro:
        'Uygulama, sürücü ve web sitesi değişiklikleri için iş akışı komutları. Rust çalışma alanı, yerel sürücü yeniden yükleme veya belge sitesi değişiklikleri için bunları kullanın.',
      commands: [
        { title: 'Rust çalışma alanı', body: '', command: devCommands.rust },
        { title: 'Sürücü yeniden yükleme', body: '', command: devCommands.driver },
        { title: 'Web sitesi', body: '', command: devCommands.website },
      ],
    },
    docLinks: [
      { title: 'Kurulum', body: 'Paket, tam kurulum ve sürücü yığını yolları.', href: '/install' },
      { title: 'Başlangıç', body: 'Kurulumdan sonraki ilk kontroller.', href: '/getting-started' },
      { title: 'GUI ve CLI', body: 'Günlük kontroller ve tekrarlanabilir terminal komutları.', href: '/gui-cli' },
      { title: 'Sürücü', body: 'casper-wmi ve Linux arayüz notları.', href: '/driver' },
      { title: 'Sorun Giderme', body: 'Destek raporu komutları ve ilk kontroller.', href: '/troubleshooting' },
      { title: 'Hakkında', body: 'Proje kapsamı, katkılar, kaynak ve lisans notları.', href: '/about' },
      { title: 'Geliştirme', body: 'Rust, sürücü yeniden yükleme ve web sitesi iş akışı.', href: '/development' },
    ],
    projectLinks: [
      { label: 'GitHub deposu', href: 'https://github.com/mert-kurttutan/cecc-linux' },
      { label: 'Sürümler', href: 'https://github.com/mert-kurttutan/cecc-linux/releases' },
      { label: 'Sorun bildir', href: 'https://github.com/mert-kurttutan/cecc-linux/issues' },
    ],
  },
}

export function localizePath(locale: Locale, path: string) {
  const page = pageFromBasePath(path)

  if (page) {
    return routePaths[locale][page]
  }

  return locale === 'tr' ? `/tr${path}` : `/en${path}`
}

export function stripLocalePath(pathname: string): { locale: Locale; path: string } {
  const normalized = pathname.replace(/\/+$/, '') || '/'

  if (normalized === '/en') {
    return { locale: 'en', path: '/' }
  }

  if (normalized.startsWith('/en/')) {
    return { locale: 'en', path: basePathFromLocalePath('en', normalized.slice(3) || '/') }
  }

  if (normalized === '/tr') {
    return { locale: 'tr', path: '/' }
  }

  if (normalized.startsWith('/tr/')) {
    return { locale: 'tr', path: basePathFromLocalePath('tr', normalized.slice(3) || '/') }
  }

  return { locale: 'tr', path: basePathFromLocalePath('tr', normalized) }
}

function pageFromBasePath(path: string): Page | undefined {
  return Object.entries(pagePaths.en).find(([, pagePath]) => pagePath === path)?.[0] as Page | undefined
}

function basePathFromLocalePath(locale: Locale, path: string) {
  const page = Object.entries(pagePaths[locale]).find(([, pagePath]) => pagePath === path)?.[0] as Page | undefined

  if (page) {
    return pagePaths.en[page]
  }

  return path
}
