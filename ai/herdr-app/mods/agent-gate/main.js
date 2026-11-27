// Native Herdr-app modal for agent-gate PERM_REQUESTs + agent-quota overview.
// Open with ctrl-shift-a or mod picker (ctrl-shift-k).
// Keys: Up/Down select, Enter allow, d deny, r refresh, Esc close.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, checking, props, closeOverlay, theme } from "herdr";

export default class AgentGateMod extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.requests = [];
    this.quotaLines = [];
    this.selected = 0;
    this.status = "";
    if (!checking()) {
      this.refresh(cx);
    }
  }

  async refresh(cx) {
    try {
      const [pendingRes, quotaRes] = await Promise.all([
        exec("ask", ["--pending"]),
        exec("agent-quota", []),
      ]);
      const raw = (pendingRes.stdout ?? "").trim();
      if (!raw || raw === "no pending permission requests") {
        this.requests = [];
      } else {
        this.requests = raw
          .split("\n")
          .filter(Boolean)
          .map((line) => {
            const parts = line.split("\t");
            return { id: parts[0], tag: parts[1] ?? "", detail: parts.slice(2).join(" ") };
          });
      }
      if (this.selected >= this.requests.length) {
        this.selected = Math.max(0, this.requests.length - 1);
      }
      this.quotaLines = (quotaRes.stdout ?? "").trim().split("\n").filter(Boolean);
    } catch (err) {
      this.status = String(err);
    }
    cx.notify();
  }

  async decide(action, cx) {
    const req = this.requests[this.selected];
    if (!req) return;
    const args = action === "allow"
      ? ["--allow", req.id, "approved via herdr-app"]
      : ["--deny", req.id, "denied via herdr-app"];
    const res = await exec("ask", args);
    this.status = (res.stdout || res.stderr || `${action} ${req.id}`).trim();
    await this.refresh(cx);
  }

  render(cx) {
    const t = theme();
    const btn = (id, label, bg, fg, onClick) =>
      h_flex()
        .id(id)
        .h(28)
        .px(10)
        .items_center()
        .rounded(6)
        .bg(bg)
        .text_color(fg)
        .text_size(12)
        .cursor_pointer()
        .hover((s) => s.opacity(0.88))
        .on_click(onClick)
        .child(label);

    return v_flex()
      .id("agent-gate-mod")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "escape") closeOverlay(props()?.overlay);
        else if (e.key === "r") this.refresh(cx);
        else if (e.key === "down" || e.key === "j") {
          this.selected = Math.min(Math.max(0, this.requests.length - 1), this.selected + 1);
          cx.notify();
        } else if (e.key === "up" || e.key === "k") {
          this.selected = Math.max(0, this.selected - 1);
          cx.notify();
        } else if (e.key === "enter") this.decide("allow", cx);
        else if (e.key === "d") this.decide("deny", cx);
        else return;
        cx.stop_propagation();
      })
      .size_full()
      .min_h(0)
      .p(16)
      .gap(12)
      .rounded(8)
      .bg(t.popover)
      .text_size(13)
      .child(
        h_flex()
          .items_center()
          .gap(8)
          .child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child("Agent Gate & Quota"))
          .child(btn("refresh", "Refresh (r)", t.raised, t.foreground, (_e, cx) => this.refresh(cx)))
          .child(div().text_size(11).text_color(t.dim).child("Esc")),
      )
      .child(
        v_flex()
          .flex_1()
          .min_h(0)
          .gap(6)
          .overflow_y_scrollbar()
          .child(div().text_size(11).font_semibold().text_color(t.muted).child("PENDING PERMISSIONS"))
          .children(
            this.requests.length === 0
              ? [div().p(10).rounded(6).bg(t.raised).text_color(t.dim).child("No pending permission requests.")]
              : this.requests.map((r, i) =>
                  h_flex()
                    .id(`req-${i}`)
                    .p(8)
                    .gap(8)
                    .items_center()
                    .rounded(6)
                    .bg(i === this.selected ? t.selection : t.raised)
                    .on_click((_e, cx) => {
                      this.selected = i;
                      cx.notify();
                    })
                    .child(
                      v_flex()
                        .flex_1()
                        .min_w(0)
                        .gap(2)
                        .child(div().text_color(t.foreground).font_semibold().child(`${r.id} ${r.tag}`))
                        .child(div().text_size(12).text_color(t.muted).child(r.detail)),
                    )
                    .child(btn(`allow-${i}`, "Allow", t.solid, t.solid_foreground, (_e, cx) => {
                      this.selected = i;
                      this.decide("allow", cx);
                    }))
                    .child(btn(`deny-${i}`, "Deny", t.raised, t.foreground, (_e, cx) => {
                      this.selected = i;
                      this.decide("deny", cx);
                    })),
                ),
          ),
      )
      .child(
        v_flex()
          .gap(4)
          .p(10)
          .rounded(6)
          .bg(t.raised)
          .child(div().text_size(11).font_semibold().text_color(t.muted).child("AGENT QUOTA"))
          .children(this.quotaLines.map((l) => div().text_size(12).text_color(t.foreground).child(l))),
      )
      .when(this.status.length > 0, (el) =>
        el.child(div().text_size(12).text_color(t.dim).child(this.status)),
      );
  }
}
