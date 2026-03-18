class Agentlinker < Formula
  desc "AI Agent Remote Control System - Cross-platform client"
  homepage "https://github.com/Royean/AgentLinker"
  url "https://github.com/Royean/AgentLinker/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "CHANGE_ME"  # 需要计算实际 SHA256
  license "MIT"
  version "2.0.0"

  depends_on "python@3.11"

  def install
    # 安装客户端代码
    libexec.install Dir["client/*"]
    libexec.install Dir["server/*"]
    
    # 创建包装脚本
    (bin/"agentlinker").write <<~EOS
      #!/usr/bin/env python3
      import sys
      import os
      sys.path.insert(0, '#{libexec}/client')
      sys.path.insert(0, '#{libexec}/client/core')
      
      from core import Config, AgentClient, generate_device_id
      
      if __name__ == "__main__":
          import argparse
          parser = argparse.ArgumentParser(description='AgentLinker Client')
          parser.add_argument('--mode', choices=['client', 'controller'], default='client')
          parser.add_argument('--config', default=ENV.get('HOME') + '/.agentlinker/config.json')
          parser.add_argument('--server', default='ws://43.98.243.80:8080/ws/client')
          parser.add_argument('--gui', action='store_true', help='Run with GUI')
          
          args = parser.parse_args()
          
          if args.gui:
              from app import AgentLinkerApp
              app = AgentLinkerApp()
              app.show_gui()
          else:
              config = Config(args.config)
              config.data = {
                  'device_id': generate_device_id(),
                  'device_name': '#{hostname}',
                  'token': 'ah_device_token_change_in_production',
                  'server_url': args.server
              }
              config.save()
              
              print(f"Device ID: {config.device_id}")
              print(f"Server: {config.server_url}")
              print("Starting client...")
              
              client = AgentClient(config)
              import asyncio
              asyncio.run(client.run())
    EOS
    
    chmod 0755, bin/"agentlinker"
    
    # 安装 launchd 服务
    (prefix/"etc").mkpath
    (prefix/"etc/agentlinker.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>com.agentlinker.client</string>
          <key>ProgramArguments</key>
          <array>
              <string>#{bin}/agentlinker</string>
              <string>--mode</string>
              <string>client</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <dict>
              <key>SuccessfulExit</key>
              <false/>
              <key>Crashed</key>
              <true/>
          </dict>
      </dict>
      </plist>
    EOS
  end

  def caveats
    <<~EOS
      AgentLinker has been installed!
      
      To use AgentLinker:
      1. Run with GUI: agentlinker --gui
      2. Run in background: agentlinker --mode client
      
      To install as a login item:
        cp #{opt_prefix}/etc/agentlinker.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/agentlinker.plist
      
      Default server: ws://43.98.243.80:8080/ws/client
      
      For more info: https://github.com/Royean/AgentLinker
    EOS
  end

  test do
    output = shell_output("#{bin}/agentlinker --help")
    assert_match "AgentLinker Client", output
  end
end
