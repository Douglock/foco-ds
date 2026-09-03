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
  await new Promise((r) => setTimeout(r, 1200));

  console.log("2. Clicando na aba Plugins...");
  await send("Runtime.evaluate", {
    expression: `
      (() => {
        const tabs = Array.from(document.querySelectorAll('.mat-mdc-tab, .mat-tab-label, button, a'));
        const pluginTab = tabs.find(t => (t.innerText || '').toLowerCase().includes('plugin'));
        if (pluginTab) pluginTab.click();
      })()
    `,
  });
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
        if (!input) return { ok: false, error: "Input não encontrado" };
        
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
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await send("Runtime.evaluate", {
      expression: `
        (() => {
          const dialogBtns = Array.from(document.querySelectorAll('mat-dialog-container button, .mat-mdc-dialog-container button, .cdk-overlay-container button'));
          for (const b of dialogBtns) {
            const t = (b.innerText || '').toLowerCase();
            if (['instalar','install','salvar','save','ok','permitir','confirm','continuar','continue','adicionar','add','carregar','load'].some(x => t.includes(x))) {
              b.click();
            }
          }
        })()
      `,
    });
    await new Promise((r) => setTimeout(r, 900));
  }

  console.log("5. Garantindo que o plugin está ATIVADO...");
  const toggleResult = await send("Runtime.evaluate", {
    expression: `
      (() => {
        const toggles = Array.from(document.querySelectorAll(
          'mat-slide-toggle input, .mdc-switch input, mat-slide-toggle button, .mat-mdc-slide-toggle button, .mat-mdc-slide-toggle, [role="switch"], input[type="checkbox"]'
        ));
        const toggle = toggles.find((candidate) => {
          let node = candidate;
          for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) {
            const text = node.innerText || '';
            if (text.includes('Foco DS') || text.includes('foco-ds')) return true;
          }
          return false;
        });
        if (!toggle) {
          const candidates = Array.from(document.querySelectorAll('button'));
          const enableButton = candidates.find((button) => {
            const label = (button.innerText || button.getAttribute('aria-label') || '').toLowerCase();
            if (!(label.includes('ativar') || label.includes('enable'))) return false;
            let node = button;
            for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) {
              const text = node.innerText || '';
              if (text.includes('Foco DS') || text.includes('foco-ds')) return true;
            }
            return false;
          });
          if (enableButton) {
            enableButton.click();
            return { found: true, wasChecked: false, clicked: true, control: 'button' };
          }
          return { found: false };
        }
        const wasChecked = Boolean(toggle.checked || toggle.getAttribute('aria-checked') === 'true');
        if (!wasChecked) toggle.click();
        return { found: true, wasChecked, clicked: !wasChecked };
      })()
    `,
    returnByValue: true
  });
  console.log("Status do Toggle:", toggleResult?.result?.value);

  await new Promise((r) => setTimeout(r, 1000));

  console.log("6. Retornando para hábitos...");
  await send("Runtime.evaluate", {
    expression: `
      window.location.hash = '#/habits';
    `,
  });

  await new Promise((r) => setTimeout(r, 800));
  ws.close();
  console.log("🎉 Plugin Foco DS instalado e ativo no Super Productivity!");
}

main().catch(console.error);
