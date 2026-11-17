---
rule: browse-not-curl
when: The agent is about to fetch, read, or scrape a web page for its content.
threshold: 0.5
---
Read sites through the browser tool (`browse`), which uses the real Chrome with existing logins and renders JavaScript. Use `curl` only for APIs, raw files, and downloads that need no session. If a plain fetch returns a login wall, a cookie banner, or an empty JS shell, that is the signal to switch — do not retry the fetch with different headers.
