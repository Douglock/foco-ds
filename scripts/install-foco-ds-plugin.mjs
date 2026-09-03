import fs from "node:fs";

async function main() {
  console.log("Conectando ao Super Productivity via CDP (127.0.0.1:9222)...");
  
  let pagesRes;
  try {
    pagesRes = await fetch("http://127.0.0.1:9222/json");
  } catch (e) {
    console.error("Super Productivity não está com porta de depuração 9222 ativa.");
    process.exit(1);
  }

  const pages = await pagesRes.json();
  const page = pages.find((p) => p.type === "page" && p.webSocketDebuggerUrl);

  if (!page) {
    console.error("Nenhuma página do Super Productivity encontrada no CDP.");
    process.exit(1);
  }

  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve) => { ws.onopen = resolve; });

  let msgId = 1;
  function send(method, params = {}) {
    return new Promise((resolve) => {
      const id = msgId++;
      const onMessage = (event) => {
        const res = JSON.parse(event.data);
        if (res.id === id) {
          ws.removeEventListener("message", onMessage);
          resolve(res.result);
        }
      };
      ws.addEventListener("message", onMessage);
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await send("Page.enable");
  await send("DOM.enable");
  await send("Runtime.enable");

  console.log("1. Navegando para Configurações...");
  await send("Runtime.evaluate", { expression: "window.location.hash = '#/config';" });
  await new Promise((r) => setTimeout(r, 1000));

  console.log("2. Clicando na aba Plugins (Tab 4 - extension)...");
  const tabResult = await send("Runtime.evaluate", {
    expression: `
      (() => {
        const tabs = Array.from(document.querySelectorAll(".mat-mdc-tab, .mat-tab-label, [role=\\"tab\\"]"));
        const extTab = tabs.find(t => t.innerText.includes("extension") || t.innerHTML.includes("extension") || (t.innerText || '').toLowerCase().includes("plugin"));
        if (extTab) {
          extTab.click();
          return { ok: true, text: extTab.innerText };
        }
        return { ok: false };
      })()
    `,
    returnByValue: true
  });
  console.log("Resultado da aba:", tabResult?.result?.value);
  await new Promise((r) => setTimeout(r, 1200));

  console.log("3. Injetando ZIP do Foco DS...");
  const zipPath = "/Users/douglassantana/.gemini/antigravity-ide/scratch/foco-ds/release/foco-ds-super-productivity.zip";
  if (!fs.existsSync(zipPath)) {
    console.error("Arquivo ZIP não encontrado em:", zipPath);
    process.exit(1);
  }

  const zipBase64 = fs.readFileSync(zipPath).toString("base64");

  const injectResult = await send("Runtime.evaluate", {
    expression: `
      (() => {
        const b64 = "${zipBase64}";
        const binary = atob(b64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
          bytes[i] = binary.charCodeAt(i);
        }
        const blob = new Blob([bytes], { type: "application/zip" });
        const file = new File([blob], "foco-ds-super-productivity.zip", { type: "application/zip" });
        
        const input = document.querySelector("input[type=\\"file\\"][accept*=\\"zip\\"]") || document.querySelector("input[type=\\"file\\"]");
        if (!input) return { ok: false, error: "Input de ZIP não encontrado" };
        
        const dt = new DataTransfer();
        dt.items.add(file);
        input.files = dt.files;
        input.dispatchEvent(new Event("change", { bubbles: true }));
        return { ok: true, size: file.size };
      })()
    `,
    returnByValue: true
  });
  console.log("Resultado da injeção:", injectResult?.result?.value);

  await new Promise((r) => setTimeout(r, 1500));

  console.log("4. Confirmando diálogos de permissão / instalação...");
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const dialogRes = await send("Runtime.evaluate", {
      expression: `
        (() => {
          const dialogBtns = Array.from(document.querySelectorAll('mat-dialog-container button, .mat-mdc-dialog-container button, .cdk-overlay-container button'));
          const clicked = [];
          for (const b of dialogBtns) {
            const t = (b.innerText || '').toLowerCase();
            if (['instalar','install','salvar','save','ok','permitir','confirm','continuar','continue','adicionar','add','carregar','load'].some(x => t.includes(x))) {
              b.click();
              clicked.push(t);
            }
          }
          return { clicked };
        })()
      `,
      returnByValue: true
    });
    console.log(`Tentativa ${attempt + 1}:`, dialogRes?.result?.value);
    await new Promise((r) => setTimeout(r, 800));
  }

  console.log("5. Verificando toggle do Foco DS...");
  const toggleResult = await send("Runtime.evaluate", {
    expression: `
      (() => {
        const rows = Array.from(document.querySelectorAll("mat-card, .mat-mdc-card, tr, li, div"));
        const focoRow = rows.find(r => (r.innerText || '').includes("Foco DS") || (r.innerText || '').includes("foco-ds"));
        if (!focoRow) {
          return { found: false, plugins: Array.from(document.querySelectorAll("h3, h4, strong")).map(h => h.innerText) };
        }
        const toggle = focoRow.querySelector('mat-slide-toggle input, .mdc-switch input, [role="switch"], input[type="checkbox"]');
        if (toggle) {
          const wasChecked = Boolean(toggle.checked || toggle.getAttribute('aria-checked') === 'true');
          if (!wasChecked) toggle.click();
          return { found: true, wasChecked, activated: !wasChecked };
        }
        return { found: true, noToggle: true };
      })()
    `,
    returnByValue: true
  });
  console.log("Status do Plugin:", toggleResult?.result?.value);

  console.log("6. Retornando para tarefas de hoje...");
  await send("Runtime.evaluate", {
    expression: `
      window.location.hash = '#/tag/TODAY/tasks';
    `,
  });

  await new Promise((r) => setTimeout(r, 1000));
  ws.close();
  console.log("🎉 Concluído!");
}

main().catch(console.error);
