# Kernel and system hardening
# Sysctl parameters, audit logging, and systemd journal persistence

{ lib, ... }:

{
  # Kernel hardening
  boot.kernel.sysctl = {
    # Hide kernel pointers from unprivileged users
    "kernel.kptr_restrict" = 2;

    # Restrict dmesg access to root
    "kernel.dmesg_restrict" = 1;

    # Disable unprivileged eBPF
    "kernel.unprivileged_bpf_disabled" = 1;

    # Restrict ptrace to parent/child processes
    "kernel.yama.ptrace_scope" = 2;

    # Network hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
  };

  # Persistent journal with size limits
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=500M
    RuntimeMaxUse=100M
  '';

  # Audit logging
  security.audit.enable = true;
  security.audit.rules = [
    # Log privilege escalation
    "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k privilege_escalation"
    # Log unauthorized access attempts
    "-a always,exit -F arch=b64 -S open,openat -F exit=-EACCES -k access_denied"
    "-a always,exit -F arch=b64 -S open,openat -F exit=-EPERM -k access_denied"
  ];
}
