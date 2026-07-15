"use strict";

// HK + A Stocks — non-mainland quote endpoints for SuperIsland.
// Primary: TradingView scanner (HKEX/SSE/SZSE). Fallback: Yahoo Finance quote.
// Mainland endpoints such as Sina, Eastmoney, Tencent Finance, and Xueqiu are
// intentionally not used.

var TV_ENDPOINTS = {
  hongkong: "https://scanner.tradingview.com/hongkong/scan",
  china: "https://scanner.tradingview.com/china/scan"
};

var YAHOO_QUOTE = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=";

var GREEN = { r: 0.28, g: 0.9, b: 0.62, a: 1 };
var RED = { r: 1, g: 0.34, b: 0.34, a: 1 };
var GOLD = { r: 1, g: 0.82, b: 0.28, a: 1 };
var DIM = { r: 1, g: 1, b: 1, a: 0.48 };
var FAINT = { r: 1, g: 1, b: 1, a: 0.28 };

var stocks = [];
var lastFetchAt = 0;
var lastFetchOK = 0;
var fetchInFlight = false;
var fetchError = null;
var heartbeatID = null;
var selectedSymbol = null;

var TV_COLUMNS = [
  "name",
  "description",
  "close",
  "change",
  "change_abs",
  "currency",
  "exchange",
  "update_mode"
];

function settingString(key, fallback) {
  var value = SuperIsland.settings.get(key);
  if (value === null || value === undefined || value === "") return fallback;
  return String(value);
}

function settingNumber(key, fallback) {
  var parsed = Number(settingString(key, fallback));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function refreshMs() {
  return Math.max(1, settingNumber("refreshMinutes", 3)) * 60 * 1000;
}

function padLeft(value, width) {
  var s = String(value || "");
  while (s.length < width) s = "0" + s;
  return s;
}

function normalizeInput(raw) {
  var text = String(raw || "").trim().toUpperCase();
  if (!text) return null;
  text = text.replace(/\s+/g, "");

  var exchange = null;
  var code = null;
  if (text.indexOf(":") > 0) {
    var parts = text.split(":");
    exchange = parts[0];
    code = parts[1];
  } else if (/^\d{4,5}\.HK$/.test(text)) {
    exchange = "HKEX";
    code = text.replace(".HK", "").replace(/^0+/, "");
  } else if (/^\d{6}\.SS$/.test(text)) {
    exchange = "SSE";
    code = text.replace(".SS", "");
  } else if (/^\d{6}\.SZ$/.test(text)) {
    exchange = "SZSE";
    code = text.replace(".SZ", "");
  } else if (/^\d{5}$/.test(text)) {
    exchange = "HKEX";
    code = text.replace(/^0+/, "");
  } else if (/^\d{6}$/.test(text)) {
    exchange = text.charAt(0) === "6" ? "SSE" : "SZSE";
    code = text;
  }

  if (exchange === "HK" || exchange === "HKG" || exchange === "SEHK") exchange = "HKEX";
  if (exchange === "SH" || exchange === "SHA") exchange = "SSE";
  if (exchange === "SZ" || exchange === "SHE") exchange = "SZSE";
  if (exchange !== "HKEX" && exchange !== "SSE" && exchange !== "SZSE") return null;
  if (!/^\d+$/.test(code)) return null;
  if (exchange === "HKEX") code = String(Number(code));
  if ((exchange === "SSE" || exchange === "SZSE") && code.length !== 6) return null;

  return {
    exchange: exchange,
    code: code,
    tv: exchange + ":" + code,
    market: exchange === "HKEX" ? "hongkong" : "china",
    yahoo: exchange === "HKEX" ? padLeft(code, 4) + ".HK" : code + (exchange === "SSE" ? ".SS" : ".SZ")
  };
}

function configuredSymbols() {
  var input = settingString("symbols", "HKEX:700, HKEX:9988, HKEX:3690, SSE:600519, SZSE:000001");
  var raw = input.split(/[,\n;]/);
  var seen = {};
  var result = [];
  for (var i = 0; i < raw.length; i++) {
    var symbol = normalizeInput(raw[i]);
    if (!symbol || seen[symbol.tv]) continue;
    seen[symbol.tv] = true;
    result.push(symbol);
  }
  if (result.length === 0) result.push(normalizeInput("HKEX:700"));
  return result.filter(function (item) { return item !== null; }).slice(0, 12);
}

function primarySymbolKey() {
  var primary = normalizeInput(settingString("primarySymbol", ""));
  return primary ? primary.tv : null;
}

function sign(value) {
  return value > 0 ? "+" : "";
}

function numberOrNull(value) {
  var n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function formatPrice(value) {
  var n = numberOrNull(value);
  if (n === null) return "--";
  if (n >= 1000) return n.toFixed(0);
  if (n >= 100) return n.toFixed(1);
  return n.toFixed(2);
}

function formatPercent(value) {
  var n = numberOrNull(value);
  if (n === null) return "--";
  return sign(n) + n.toFixed(2) + "%";
}

function formatAbs(value) {
  var n = numberOrNull(value);
  if (n === null) return "";
  return sign(n) + formatPrice(n);
}

function marketLabel(stock) {
  if (stock.exchange === "HKEX") return "HK";
  if (stock.exchange === "SSE") return "SH";
  if (stock.exchange === "SZSE") return "SZ";
  return stock.exchange || "";
}

function quoteColor(stock) {
  var change = numberOrNull(stock.changePercent);
  if (change === null || change === 0) return "gray";
  return change > 0 ? RED : GREEN;
}

function sourceDelayLabel(stock) {
  if (stock.exchange === "HKEX") return "HK quote may be delayed ~15m";
  return "Delayed quote";
}

function mapTradingViewRow(symbolMap, row) {
  var values = row && row.d ? row.d : [];
  var meta = symbolMap[row && row.s];
  if (!meta) return null;
  return {
    symbol: meta.tv,
    code: meta.code,
    exchange: meta.exchange,
    yahoo: meta.yahoo,
    name: values[1] || values[0] || meta.code,
    price: numberOrNull(values[2]),
    changePercent: numberOrNull(values[3]),
    changeAbs: numberOrNull(values[4]),
    currency: values[5] || (meta.exchange === "HKEX" ? "HKD" : "CNY"),
    source: "TradingView",
    updateMode: values[7] || "",
    updatedAt: Date.now()
  };
}

function mergeFresh(fresh, symbols) {
  var order = {};
  for (var i = 0; i < symbols.length; i++) order[symbols[i].tv] = i;
  fresh.sort(function (a, b) { return (order[a.symbol] || 0) - (order[b.symbol] || 0); });
  stocks = fresh;
  lastFetchOK = Date.now();
  if (!selectedSymbol && stocks.length > 0) selectedSymbol = chooseInitialSelection();
}

function chooseInitialSelection() {
  var primary = primarySymbolKey();
  if (primary) {
    for (var i = 0; i < stocks.length; i++) if (stocks[i].symbol === primary) return primary;
  }
  return stocks.length > 0 ? stocks[0].symbol : null;
}

function fetchTradingView(symbols) {
  var groups = { hongkong: [], china: [] };
  for (var i = 0; i < symbols.length; i++) groups[symbols[i].market].push(symbols[i]);

  var pending = 0;
  var finished = 0;
  var fresh = [];
  var symbolMap = {};
  var hadHTTPError = false;

  for (var j = 0; j < symbols.length; j++) symbolMap[symbols[j].tv] = symbols[j];

  function done() {
    finished += 1;
    if (finished < pending) return;
    if (fresh.length > 0) {
      fetchError = null;
      fetchInFlight = false;
      mergeFresh(fresh, symbols);
      return;
    }
    fetchYahoo(symbols, hadHTTPError ? "TradingView unavailable" : "No quote rows");
  }

  ["hongkong", "china"].forEach(function (market) {
    if (groups[market].length === 0) return;
    pending += 1;
    var tickers = groups[market].map(function (item) { return item.tv; });
    var body = JSON.stringify({
      symbols: { tickers: tickers, query: { types: [] } },
      columns: TV_COLUMNS
    });

    SuperIsland.http.fetch(TV_ENDPOINTS[market], {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: body
    }).then(function (res) {
      if (!res || res.status !== 200 || !res.data || !res.data.data) {
        hadHTTPError = true;
        done();
        return;
      }
      var rows = res.data.data || [];
      for (var k = 0; k < rows.length; k++) {
        var stock = mapTradingViewRow(symbolMap, rows[k]);
        if (stock && stock.price !== null) fresh.push(stock);
      }
      done();
    });
  });

  if (pending === 0) fetchYahoo(symbols, "No symbols");
}

function mapYahooQuote(symbols, quote) {
  var byYahoo = {};
  for (var i = 0; i < symbols.length; i++) byYahoo[symbols[i].yahoo] = symbols[i];
  var meta = byYahoo[quote && quote.symbol];
  if (!meta) return null;
  return {
    symbol: meta.tv,
    code: meta.code,
    exchange: meta.exchange,
    yahoo: meta.yahoo,
    name: quote.shortName || quote.longName || quote.displayName || meta.code,
    price: numberOrNull(quote.regularMarketPrice),
    changePercent: numberOrNull(quote.regularMarketChangePercent),
    changeAbs: numberOrNull(quote.regularMarketChange),
    currency: quote.currency || (meta.exchange === "HKEX" ? "HKD" : "CNY"),
    source: "Yahoo Finance",
    updateMode: quote.quoteSourceName || "",
    updatedAt: Date.now()
  };
}

function fetchYahoo(symbols, reason) {
  var yahooSymbols = symbols.map(function (item) { return item.yahoo; }).join(",");
  SuperIsland.http.fetch(YAHOO_QUOTE + encodeURIComponent(yahooSymbols), {
    headers: { "Accept": "application/json" }
  }).then(function (res) {
    fetchInFlight = false;
    if (!res || res.status !== 200 || !res.data || !res.data.quoteResponse) {
      fetchError = reason || (res && res.error ? String(res.error) : "Quote service unavailable");
      return;
    }
    var rows = res.data.quoteResponse.result || [];
    var fresh = [];
    for (var i = 0; i < rows.length; i++) {
      var stock = mapYahooQuote(symbols, rows[i]);
      if (stock && stock.price !== null) fresh.push(stock);
    }
    if (fresh.length === 0) {
      fetchError = reason || "No quote rows";
      return;
    }
    fetchError = null;
    mergeFresh(fresh, symbols);
  });
}

function refreshNow() {
  if (fetchInFlight) return;
  var symbols = configuredSymbols();
  fetchInFlight = true;
  lastFetchAt = Date.now();
  fetchTradingView(symbols);
}

function heartbeat() {
  if (Date.now() - lastFetchAt >= refreshMs()) refreshNow();
}

function selectedStock() {
  if (stocks.length === 0) return null;
  var primary = selectedSymbol || chooseInitialSelection();
  for (var i = 0; i < stocks.length; i++) {
    if (stocks[i].symbol === primary) return stocks[i];
  }
  return stocks[Math.floor(Date.now() / 8000) % stocks.length];
}

function stockRow(stock, actionID) {
  var color = quoteColor(stock);
  return View.button(
    View.hstack([
      View.vstack([
        View.hstack([
          View.text(marketLabel(stock), { style: "footnote", color: FAINT }),
          View.text(stock.code, { style: "monospacedSmall", color: "white" })
        ], { spacing: 4, align: "center" }),
        View.text(stock.name, { style: "footnote", color: DIM, lineLimit: 1 })
      ], { spacing: 2, align: "leading" }),
      View.spacer(),
      View.vstack([
        View.text(formatPrice(stock.price), { style: "monospaced", color: "white" }),
        View.text(formatPercent(stock.changePercent), { style: "monospacedSmall", color: color })
      ], { spacing: 2, align: "trailing" })
    ], { spacing: 8, align: "center" }),
    actionID
  );
}

function emptyView() {
  return View.frame(
    View.vstack([
      View.icon("chart.line.uptrend.xyaxis", { size: 18, color: FAINT }),
      View.text(fetchError ? fetchError : "Loading quotes…", { style: "footnote", color: DIM, lineLimit: 2 })
    ], { spacing: 6, align: "center" }),
    { maxWidth: 9999, maxHeight: 9999, alignment: "center" }
  );
}

function compactView() {
  var stock = selectedStock();
  if (!stock) {
    return View.hstack([
      View.icon("chart.line.uptrend.xyaxis", { size: 12, color: GOLD }),
      View.text(fetchError ? "Quotes offline" : "Loading quotes", { style: "footnote", color: DIM })
    ], { spacing: 6, align: "center" });
  }
  return View.hstack([
    View.text(marketLabel(stock), { style: "footnote", color: FAINT }),
    View.text(stock.code, { style: "monospacedSmall", color: "white" }),
    View.text(formatPrice(stock.price), { style: "monospaced", color: "white" }),
    View.text(formatPercent(stock.changePercent), { style: "monospacedSmall", color: quoteColor(stock) })
  ], { spacing: 6, align: "center" });
}

function expandedView() {
  var stock = selectedStock();
  if (!stock) return emptyView();
  return View.hstack([
    View.icon("chart.line.uptrend.xyaxis", { size: 18, color: quoteColor(stock) }),
    View.vstack([
      View.hstack([
        View.text(marketLabel(stock) + " " + stock.code, { style: "caption", color: "white" }),
        View.text(stock.currency || "", { style: "footnote", color: FAINT })
      ], { spacing: 5, align: "center" }),
      View.text(stock.name, { style: "footnote", color: DIM, lineLimit: 1 }),
      View.text(sourceDelayLabel(stock), { style: "footnote", color: FAINT, lineLimit: 1 })
    ], { spacing: 3, align: "leading" }),
    View.spacer(),
    View.vstack([
      View.text(formatPrice(stock.price), { style: "title", color: "white" }),
      View.text(formatAbs(stock.changeAbs) + "  " + formatPercent(stock.changePercent), { style: "monospacedSmall", color: quoteColor(stock) })
    ], { spacing: 3, align: "trailing" })
  ], { spacing: 10, align: "center" });
}

function fullExpandedView() {
  if (stocks.length === 0) return emptyView();
  var ageSec = lastFetchOK ? Math.max(0, Math.round((Date.now() - lastFetchOK) / 1000)) : null;
  var rows = [];
  for (var i = 0; i < stocks.length; i++) rows.push(stockRow(stocks[i], "select:" + stocks[i].symbol));

  return View.vstack([
    View.hstack([
      View.icon("chart.line.uptrend.xyaxis", { size: 13, color: GOLD }),
      View.text("HK + A Stocks", { style: "caption", color: "white" }),
      View.spacer(),
      View.button(View.icon("arrow.clockwise", { size: 10, color: DIM }), "refresh")
    ], { spacing: 6, align: "center" }),
    View.scroll(
      View.vstack(rows, { spacing: 5, align: "leading" }),
      { axes: "vertical", showsIndicators: false }
    ),
    View.hstack([
      View.text(
        fetchError ? fetchError :
          ((ageSec === null ? "Loading" : "Updated " + ageSec + "s ago") + " · " +
            (stocks[0].source || "Quote data") + " · HK delayed"),
        { style: "footnote", color: FAINT, lineLimit: 1 }
      ),
      View.spacer(),
      View.text("No mainland quote endpoints", { style: "footnote", color: FAINT, lineLimit: 1 })
    ], { spacing: 8, align: "center" })
  ], { spacing: 7, align: "leading" });
}

SuperIsland.registerModule({
  onActivate: function () {
    refreshNow();
    if (heartbeatID === null) heartbeatID = setInterval(heartbeat, 15000);
  },

  onDeactivate: function () {
    if (heartbeatID !== null) { clearInterval(heartbeatID); heartbeatID = null; }
  },

  onSettingsChanged: function () {
    selectedSymbol = null;
    lastFetchAt = 0;
    refreshNow();
  },

  onAction: function (actionID) {
    if (actionID === "refresh") {
      lastFetchAt = 0;
      refreshNow();
      return;
    }
    if (actionID.indexOf("select:") === 0) {
      selectedSymbol = actionID.slice(7);
      SuperIsland.playFeedback("selection");
    }
  },

  compact: compactView,

  minimalCompact: {
    leading: function () {
      var stock = selectedStock();
      var code = stock ? marketLabel(stock) + stock.code : "--";
      return View.text(code, { style: "monospacedSmall", color: stock ? "white" : DIM, lineLimit: 1 });
    },
    trailing: function () {
      var stock = selectedStock();
      return View.text(stock ? formatPrice(stock.price) : "--", { style: "monospacedSmall", color: stock ? quoteColor(stock) : DIM, lineLimit: 1 });
    },
    precedence: function () { return 1; }
  },

  expanded: expandedView,
  fullExpanded: fullExpandedView
});
