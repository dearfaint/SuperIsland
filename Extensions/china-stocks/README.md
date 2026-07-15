# HK + A Stocks

Shows Hong Kong and China A-share quotes inside SuperIsland.

Supported symbol examples:
- Hong Kong: `HK:00990`, `HKEX:990`, `00990.HK`, `0990.HK`
- Shanghai A: `SH:600519`, `SSE:600519`, `600519.SS`
- Shenzhen A: `SZ:000001`, `SZSE:000001`, `000001.SZ`

Data sources:
- Primary: TradingView scanner endpoints (`scanner.tradingview.com`) for HKEX, SSE, and SZSE symbols.
- Fallback: Yahoo Finance quote endpoint for `.HK`, `.SS`, and `.SZ` symbols.

This extension intentionally avoids mainland quote endpoints such as Sina, Eastmoney, Tencent Finance, or Xueqiu. Hong Kong quotes may be delayed, commonly by about 15 minutes depending on exchange entitlement and upstream availability.
