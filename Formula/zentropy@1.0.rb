class ZentropyAT10 < Formula
  desc "High-performance, lightweight key-value store server (Redis alternative)"
  homepage "https://github.com/mailmug/zentropy"
  url "https://github.com/mailmug/zentropy/releases/download/v1.0.0/zentropy.zip"
  sha256 "250cf01f3f86cf8607025f422c221e9f90c9824f1b4c53c2aed943a8b3a59aa4"
  license "MIT"

  depends_on "unzip" => :build if OS.mac?

  def install
    # Extract the ZIP archive
    if File.exist?("zentropy.zip")
      if OS.mac?
        system "unzip", "-o", "zentropy.zip"
      else
        system "unzip", "-o", "zentropy.zip"
      end
    end

    # Determine the right binary based on architecture
    binary_path = if OS.mac?
      if Hardware::CPU.arm?
        "aarch64-macos/zentropty"
      else
        "x86_64-macos/zentropty"
      end
    else
      if Hardware::CPU.arm?
        "aarch64-linux-gnu/zentropty"
      else
        "x86_64-linux-gnu/zentropty"
      end
    end

    # Install binary
    bin.install binary_path => "zentropy"

    # Create configuration directory and sample config
    (etc/"zentropy").mkpath
    (etc/"zentropy/zentropy.conf").write default_config unless (etc/"zentropy/zentropy.conf").exist?

    # Create data directory
    (var/"zentropy").mkpath

    # Install launchd plist for macOS
    if OS.mac?
      (pkgshare/"homebrew.mxcl.zentropy.plist").write macos_plist
      (pkgshare/"homebrew.mxcl.zentropy.plist").chmod 0644
    end

    # Install systemd service for Linux
    if OS.linux?
      (pkgshare/"zentropy.service").write linux_service
      (pkgshare/"zentropy.service").chmod 0644
    end
  end

  def post_install
    return unless OS.mac?
    # Link launchd plist on macOS
    ln_sf etc/"homebrew.mxcl.zentropy.plist", prefix/"homebrew.mxcl.zentropy.plist"
  end

  service do
    run [opt_bin/"zentropy", etc/"zentropy/zentropy.conf"]
    working_dir var/"zentropy"
    keep_alive true
    log_path var/"log/zentropy.log"
    error_log_path var/"log/zentropy.error.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      Zentropy has been installed!

      Configuration file: #{etc}/zentropy/zentropy.conf
      Data directory: #{var}/zentropy

      To start zentropy now and restart at login:
        brew services start zentropy

      Or, if you don't want/need a background service you can just run:
        zentropy #{etc}/zentropy/zentropy.conf

      To reload the configuration after changes, restart the service:
        brew services restart zentropy
    EOS
  end

  test do
    assert_match "zentropy", shell_output("#{bin}/zentropy --version")
  end

  private

  def default_config
    <<~EOS
      # Zentropy Configuration File
      # Located at: #{etc}/zentropy/zentropy.conf

      # Network settings
      port = 6383
      host = "127.0.0.1"

      # Data persistence
      data_dir = "#{var}/zentropy"
      appendonly = yes
      appendfsync = everysec

      # Memory settings
      max_memory = 100mb
      max_memory_policy = allkeys-lru

      # Logging
      log_level = info
      log_file = "#{var}/log/zentropy.log"

      # Performance
      threads = 4
      timeout = 300
    EOS
  end

  def macos_plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>homebrew.mxcl.zentropy</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/zentropy</string>
          <string>#{etc}/zentropy/zentropy.conf</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{var}/zentropy</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/zentropy.log</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/zentropy.error.log</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>ProcessType</key>
        <string>Background</string>
        <key>UserName</key>
        <string>#{ENV["USER"]}</string>
      </dict>
      </plist>
    EOS
  end

  def linux_service
    <<~EOS
      [Unit]
      Description=Zentropy key-value store server
      After=network.target
      Wants=network.target

      [Service]
      Type=simple
      User=#{ENV["USER"]}
      WorkingDirectory=#{var}/zentropy
      ExecStart=#{opt_bin}/zentropy #{etc}/zentropy/zentropy.conf
      Restart=always
      RestartSec=5
      StandardOutput=file:#{var}/log/zentropy.log
      StandardError=file:#{var}/log/zentropy.error.log

      [Install]
      WantedBy=multi-user.target
    EOS
  end
end