export type Page =
  | 'home'
  | 'install'
  | 'getting-started'
  | 'gui-cli'
  | 'driver'
  | 'troubleshooting'
  | 'development'

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

export const navItems: NavItem[] = [
  { label: 'Home', href: '/', page: 'home' },
  { label: 'Install', href: '/install', page: 'install' },
  { label: 'Getting Started', href: '/getting-started', page: 'getting-started' },
  { label: 'GUI & CLI', href: '/gui-cli', page: 'gui-cli' },
  { label: 'Driver', href: '/driver', page: 'driver' },
  { label: 'Troubleshooting', href: '/troubleshooting', page: 'troubleshooting' },
  { label: 'Development', href: '/development', page: 'development' },
]

export const installOptions: CardItem[] = [
  {
    title: 'Full stack',
    body: 'App, permission rules, and DKMS driver.',
    command:
      'curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | sudo bash',
  },
  {
    title: 'Debian / Ubuntu',
    body: 'GUI, CLI, udev rules, and permission helper.',
    command:
      'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center_0.1.33_amd64.deb\nsudo apt install ./excalibur-control-center_0.1.33_amd64.deb',
  },
  {
    title: 'Fedora / RPM',
    body: 'GUI, CLI, udev rules, and permission helper.',
    command:
      'wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.33/excalibur-control-center-0.1.33-1.x86_64.rpm\nsudo dnf install ./excalibur-control-center-0.1.33-1.x86_64.rpm',
  },
]

export const valueSections: CardItem[] = [
  {
    title: 'Laptop controls',
    body: 'Change display mode, system profile, and keyboard RGB from Linux without booting the vendor app.',
  },
  {
    title: 'Linux interfaces',
    body: 'The casper-wmi driver exposes fan telemetry, LEDs, sysfs controls, hwmon, and platform profiles.',
  },
  {
    title: 'Useful diagnostics',
    body: 'The CLI can generate read-only support reports for driver, WMI, LED, hwmon, and permission issues.',
  },
]

export const firstRunSteps: CardItem[] = [
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
]

export const workflowCards: CardItem[] = [
  {
    title: 'GUI',
    body: 'Desktop controls for profiles, display mode, lighting, telemetry, and diagnostics.',
    command: 'excalibur-control-center-gui',
  },
  {
    title: 'CLI',
    body: 'Scriptable access to status, GPU mode, keyboard zones, and support reports.',
    command:
      'excalibur-control-center-cli status\nexcalibur-control-center-cli gpu get\nexcalibur-control-center-cli keyboard get all',
  },
  {
    title: 'Support report',
    body: 'Collect read-only diagnostics when checking a new model or reporting a bug.',
    command: 'excalibur-control-center-cli doctor\nexcalibur-control-center-cli doctor --include-dmesg',
  },
]

export const driverCards: CardItem[] = [
  {
    title: 'Kernel module',
    body: 'casper-wmi is an out-of-tree driver for Casper Excalibur WMI controls.',
    command: 'lsmod | grep casper_wmi\nls /sys/module/casper_wmi',
  },
  {
    title: 'Linux subsystems',
    body: 'Controls are exposed through sysfs, LEDs, hwmon, and platform profile interfaces.',
    command: 'cat /sys/firmware/acpi/platform_profile\nls /sys/class/hwmon',
  },
  {
    title: 'Development reload',
    body: 'Use the repo reload script when testing local driver changes.',
    command: 'nix develop\nnu ./scripts/reload.nu',
  },
]

export const troubleshootingItems = [
  'Run doctor first; it is read-only by default.',
  'Use --include-dmesg when reporting driver or WMI problems.',
  'If permissions fail, verify group membership and log in again.',
  'If controls are missing, check that casper-wmi is loaded.',
]

export const docLinks: DocLink[] = [
  {
    title: 'Install',
    body: 'Package, full installer, and driver-stack paths.',
    href: '/install',
  },
  {
    title: 'Getting Started',
    body: 'First-run checks after installation.',
    href: '/getting-started',
  },
  {
    title: 'GUI & CLI',
    body: 'Daily controls and repeatable terminal commands.',
    href: '/gui-cli',
  },
  {
    title: 'Driver',
    body: 'casper-wmi and Linux interface notes.',
    href: '/driver',
  },
  {
    title: 'Troubleshooting',
    body: 'Support report commands and first checks.',
    href: '/troubleshooting',
  },
  {
    title: 'Development',
    body: 'Rust, driver reload, and website workflow.',
    href: '/development',
  },
]

export const projectLinks: LinkItem[] = [
  { label: 'GitHub repository', href: 'https://github.com/mert-kurttutan/cecc-linux' },
  { label: 'Releases', href: 'https://github.com/mert-kurttutan/cecc-linux/releases' },
  { label: 'Report an issue', href: 'https://github.com/mert-kurttutan/cecc-linux/issues' },
]

export const devCommands: CardItem[] = [
  {
    title: 'Rust workspace',
    body: '',
    command:
      'cd excalibur-control-center\ncargo build\ncargo run -p excalibur-control-center-cli -- doctor\ncargo run -p excalibur-control-center-gui',
  },
  {
    title: 'Driver reload',
    body: '',
    command: 'nix develop\nnu ./scripts/reload.nu',
  },
  {
    title: 'Website',
    body: '',
    command: 'cd website\nnpm install\nnpm run dev\nnpm run check\nnpm run build',
  },
]
