(() => {
  const url = new URL(location.href);
  if (!["http:", "https:"].includes(url.protocol)) return "[]";
  return JSON.stringify(rules.filter(rule =>
    url.hostname === rule.host && url.pathname.startsWith(rule.pathPrefix)
  ).map(rule => {
    const text = (document.body?.innerText || "").replace(/\s+/g, " ");
    const success = document.readyState === "complete" && rule.contains.length > 0 &&
      rule.contains.every(phrase => text.includes(phrase));
    return { rule: rule.id, status: success ? "success" : "candidate" };
  }));
})()
