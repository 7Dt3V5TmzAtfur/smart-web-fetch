  文件结构：
```
   D:\test\smart-web-fetch\
   ├── skill.json           # Skill 配置文件
   ├── smart-web-fetch.ps1  # Windows PowerShell 主脚本
   ├── smart-web-fetch      # Unix/Linux/macOS Bash 主脚本
   ├── fetch_scrapling.py   # Scrapling 反爬处理模块
   └── .gitignore
```
  核心功能：
   - 四级降级策略：Jina Reader → markdown.new → defuddle.md → Scrapling → 基础抓取
   - 自动检测反爬拦截：识别 captcha、403、cloudflare 等并自动降级
   - 干净 Markdown 输出：节省 50-80% Token 消耗
   - JSON 格式输出：便于程序处理
