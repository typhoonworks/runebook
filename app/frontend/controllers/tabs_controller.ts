import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"] as const;
  static classes = ["active"] as const;

  declare readonly tabTargets: HTMLElement[];
  declare readonly panelTargets: HTMLElement[];
  declare readonly activeClass: string;

  connect() {
    // Ensure the first panel is shown by default
    this.showPanel(this.getActivePanelName());
  }

  select(event: Event) {
    const target = event.currentTarget as HTMLElement;
    const panelName = target.dataset.tabsPanelParam;

    if (!panelName) return;

    this.activateTab(target);
    this.showPanel(panelName);
  }

  private activateTab(activeTab: HTMLElement) {
    this.tabTargets.forEach((tab) => {
      if (tab === activeTab) {
        tab.classList.add(this.activeClass);
      } else {
        tab.classList.remove(this.activeClass);
      }
    });
  }

  private showPanel(panelName: string) {
    this.panelTargets.forEach((panel) => {
      if (panel.dataset.tabsPanelName === panelName) {
        panel.classList.remove("hidden");
      } else {
        panel.classList.add("hidden");
      }
    });
  }

  private getActivePanelName(): string {
    const activeTab = this.tabTargets.find((tab) =>
      tab.classList.contains(this.activeClass),
    );
    return activeTab?.dataset.tabsPanelParam || "storage";
  }
}
