/* Shared editing: three-way merge plus an explicit choice for overlapping edits. */
(function (root) {
  "use strict";
  const clone = value => JSON.parse(JSON.stringify(value || {}));
  function stable(value) {
    if (value == null || value === "" || (Array.isArray(value) && !value.length)) return null;
    if (Array.isArray(value)) return value.map(stable);
    if (typeof value === "object") {
      return Object.fromEntries(Object.keys(value).sort().filter(k => stable(value[k]) !== null)
        .map(k => [k, stable(value[k])]));
    }
    return value;
  }
  const equal = (a, b) => JSON.stringify(stable(a)) === JSON.stringify(stable(b));
  function applyChanges(serverData, originalUi, currentUi) {
    const data = clone(serverData);
    for (const key of new Set([...Object.keys(originalUi), ...Object.keys(currentUi)])) {
      if (!equal(originalUi[key], currentUi[key])) {
        if (Object.prototype.hasOwnProperty.call(currentUi, key)) data[key] = currentUi[key];
        else delete data[key];
      }
    }
    return data;
  }
  function groupKey(key) {
    if (key === "mtmi_csapat_letszam" || /^mtmi_csapat_tag\d+_/.test(key)) return "MTMI-csapat tagjai";
    const link = key.match(/^(.*_link)\d*$/);
    if (link) return link[1];
    const contact = key.match(/^(mtmi_felelos_kapcsolattarto|intezmenyvezeto_kapcsolattarto)_/);
    return contact ? contact[1] : key;
  }
  function merge(base, mine, server) {
    const result = clone(server);
    const groups = new Map();
    for (const key of new Set([...Object.keys(base || {}), ...Object.keys(mine), ...Object.keys(server)])) {
      const group = groupKey(key);
      if (!groups.has(group)) groups.set(group, []);
      groups.get(group).push(key);
    }
    const conflicts = [];
    const pick = (data, keys) => Object.fromEntries(keys.filter(k => Object.prototype.hasOwnProperty.call(data, k)).map(k => [k, data[k]]));
    for (const [group, keys] of groups) {
      const local = pick(mine, keys), remote = pick(server, keys);
      const old = base === null ? null : pick(base, keys);
      let choice;
      if (equal(local, remote)) choice = remote;
      else if (base !== null && equal(local, old)) choice = remote;
      else if (base !== null && equal(remote, old)) choice = local;
      else if (base === null && equal(local, {})) choice = remote;
      else if (base === null && equal(remote, {})) choice = local;
      else {
        conflicts.push({group, keys, mine: local, server: remote});
        continue;
      }
      for (const key of keys) delete result[key];
      Object.assign(result, choice);
    }
    return {data: result, conflicts};
  }
  function resolve(result, choices) {
    const data = clone(result.data);
    result.conflicts.forEach((item, i) => {
      if (choices[i] !== "mine" && choices[i] !== "server") throw new Error("Unresolved form conflict");
      item.keys.forEach(k => delete data[k]);
      Object.assign(data, item[choices[i]]);
    });
    return data;
  }
  function download(data, filename) {
    const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], {type: "application/json"}));
    const a = document.createElement("a");
    a.href = url; a.download = filename; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function review(result, label, title) {
    return new Promise(done => {
      const dialog = document.createElement("dialog");
      dialog.id = "mtmi-conflict-dialog";
      dialog.style.cssText = "width:min(1000px,96vw);max-height:90vh;border:1px solid #cbd5e1;border-radius:14px;padding:24px;overflow:auto";
      const heading = document.createElement("h2");
      heading.id = "mtmi-conflict-title";
      heading.textContent = title || "Egyeztessük a közös pályázat változtatásait";
      dialog.setAttribute("aria-labelledby", heading.id);
      dialog.append(heading);
      const intro = document.createElement("p");
      intro.textContent = "Az eltérő mezőknél válaszd ki a megtartandó változatot. A többi módosítást együtt őrizzük meg. A választás után az űrlapon még szerkesztheted a szövegeket.";
      dialog.append(intro);
      const choices = [];
      const apply = document.createElement("button");
      apply.type = "button"; apply.className = "btn btn-primary";
      apply.textContent = "Választások alkalmazása";
      apply.disabled = result.conflicts.length > 0;
      for (const [i, item] of result.conflicts.entries()) {
        const fieldset = document.createElement("fieldset");
        fieldset.style.cssText = "border:1px solid #cbd5e1;border-radius:8px;padding:16px;margin-bottom:18px";
        const legend = document.createElement("legend");
        legend.style.cssText = "font-size:1.05rem;font-weight:600";
        legend.textContent = item.keys.length === 1 ? label(item.keys[0]) : label(item.group);
        fieldset.append(legend);
        const columns = document.createElement("div");
        columns.style.cssText = "display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px";
        for (const side of ["server", "mine"]) {
          const box = document.createElement("label");
          box.style.cssText = "display:block;cursor:pointer;background:#f8fafc;padding:12px;border-radius:6px";
          const radio = document.createElement("input");
          radio.type = "radio"; radio.name = "merge-choice-" + i; radio.value = side;
          radio.addEventListener("change", () => {
            choices[i] = side;
            apply.disabled = !result.conflicts.every((_, j) => choices[j]);
          });
          box.append(radio, document.createTextNode(side === "mine" ? " Saját változat / piszkozat" : " Már elmentett változat"));
          const values = Object.entries(item[side]);
          if (!values.length) {
            const empty = document.createElement("p"); empty.textContent = "(üres)"; box.append(empty);
          }
          for (const [key, value] of values) {
            if (item.keys.length > 1) {
              const caption = document.createElement("strong"); caption.textContent = label(key); box.append(caption);
            }
            const text = document.createElement("pre");
            text.style.cssText = "white-space:pre-wrap;overflow-wrap:anywhere;font:inherit;margin:8px 0;max-height:240px;overflow:auto";
            text.textContent = Array.isArray(value) ? value.join(", ") : String(value ?? "");
            box.append(text);
          }
          columns.append(box);
        }
        fieldset.append(columns); dialog.append(fieldset);
      }
      const buttons = document.createElement("div");
      buttons.style.cssText = "display:flex;gap:12px;flex-wrap:wrap;position:sticky;bottom:-24px;background:white;padding:16px 0";
      const cancel = document.createElement("button");
      cancel.type = "button"; cancel.className = "btn btn-outline-secondary"; cancel.textContent = "Később egyeztetem";
      const exportButton = document.createElement("button");
      exportButton.type = "button"; exportButton.className = "btn btn-outline-secondary"; exportButton.textContent = "Mindkét változat letöltése";
      exportButton.onclick = () => download(result, "mtmi-valtozatok.json");
      function finish(value) { dialog.close(); dialog.remove(); done(value); }
      cancel.onclick = () => finish(null);
      dialog.addEventListener("cancel", event => { event.preventDefault(); finish(null); });
      apply.onclick = () => finish(resolve(result, choices));
      buttons.append(apply, cancel, exportButton); dialog.append(buttons);
      document.body.append(dialog); dialog.showModal();
    });
  }
  const api = {clone, equal, applyChanges, merge, resolve, review, download};
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  if (root) root.MtmiConcurrency = api;
})(typeof window !== "undefined" ? window : null);

