import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLDivElement> {
  static targets = ["list", "template", "emptyState"] as const

  declare readonly listTarget: HTMLDivElement
  declare readonly templateTarget: HTMLTemplateElement
  declare readonly emptyStateTarget: HTMLDivElement
  declare readonly hasEmptyStateTarget: boolean
  private observer?: MutationObserver

  connect() {
    this.toggleEmptyState()
    this.observer = new MutationObserver(() => this.toggleEmptyState())
    this.observer.observe(this.listTarget, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  addMarkdownAfter(event?: Event) {
    const tpl = this.templateTarget
    if (!tpl || !tpl.content) return
    const fragment = tpl.content.cloneNode(true)

    // Insert after the cell whose button was clicked; fallback to end
    if (!this.insertAfterAnchor(fragment, event)) {
      this.listTarget.appendChild(fragment)
    }
    // Activate the newly added cell and open it in edit mode
    queueMicrotask(() => {
      const el = this.listTarget.querySelector('[data-controller="markdown-cell"]:last-of-type') as HTMLElement | null
      if (!el) return
      const controller = (this.application as any).getControllerForElementAndIdentifier?.(el, "markdown-cell")
      if (controller && typeof controller.startEditing === "function") {
        controller.startEditing()
      } else {
        // Fallback: dispatch activation event so it at least gains focus
        const evt = new CustomEvent("markdown-cell:activate", { detail: { id: Math.random().toString(36).slice(2) } })
        window.dispatchEvent(evt)
      }
    })
  }

  addRubyAfter(event?: Event) {
    const tpl = document.getElementById("ruby-cell-template") as HTMLTemplateElement | null
    if (!tpl || !tpl.content) return
    const fragment = tpl.content.cloneNode(true)

    if (!this.insertAfterAnchor(fragment, event)) {
      this.listTarget.appendChild(fragment)
    }
  }

  toggleBlockMenu(event: Event) {
    const btn = event.currentTarget as HTMLElement
    const container = btn.closest(
      '[data-controller="ruby-cell"], [data-controller="markdown-cell"], [data-controller="inline-heading"], [data-el-insert-buttons]',
    ) as HTMLElement | null
    if (!container) return
    // Close any other open menus first
    this.closeAllMenus()
    const menu =
      btn.parentElement?.querySelector('[data-block-menu]') ||
      container.querySelector('[data-block-menu]')
    if (menu) {
      menu.classList.toggle('hidden')
      // Click outside to close
      const onClickOutside = (e: MouseEvent) => {
        if (!menu.contains(e.target as Node) && e.target !== btn) {
          menu.classList.add('hidden')
          window.removeEventListener('click', onClickOutside)
        }
      }
      window.addEventListener('click', onClickOutside)
    }
  }

  chooseBlockMarkdown(event: Event) {
    this.closeAllMenus()
    this.addMarkdownAfter(event)
  }

  chooseBlockSection(event: Event) {
    this.closeAllMenus()
    this.addSectionAfter(event)
  }

  addSectionAfter(event?: Event) {
    const tpl = document.getElementById('section-template') as HTMLTemplateElement | null
    if (!tpl || !tpl.content) return
    const fragment = tpl.content.cloneNode(true)

    if (!this.insertAfterAnchor(fragment, event)) {
      this.listTarget.appendChild(fragment)
    }
  }

  private closeAllMenus() {
    this.listTarget.querySelectorAll('[data-block-menu]').forEach((el) => el.classList.add('hidden'))
  }

  moveSectionUp(event: Event) {
    this.moveSection(event, -1)
  }

  moveSectionDown(event: Event) {
    this.moveSection(event, 1)
  }

  deleteSection(event: Event) {
    const target = event.currentTarget as HTMLElement
    const sectionWrapper = target.closest('.mb-4') as HTMLElement | null
    const sectionHeader = sectionWrapper?.querySelector('[data-controller="inline-heading"]') as HTMLElement | null
    if (!sectionWrapper || !sectionHeader) return

    const elements = this.collectSectionElements(sectionHeader)
    elements.forEach((el) => el.remove())
    this.dispatchChange()
  }

  private moveSection(event: Event, offset: number) {
    const target = event.target as HTMLElement
    // Find the section wrapper (.mb-4) first, then get its inline-heading
    const sectionWrapper = target.closest('.mb-4')
    if (!sectionWrapper) return

    const sectionHeader = sectionWrapper.querySelector('[data-controller="inline-heading"]')
    if (!sectionHeader) return

    // Get all section header wrappers
    const allWrappers = Array.from(
      this.listTarget.querySelectorAll('.mb-4')
    ).filter(el => el.querySelector('[data-controller="inline-heading"]'))

    const currentIndex = allWrappers.indexOf(sectionWrapper as Element)
    const targetIndex = currentIndex + offset

    // Boundary checks
    if (targetIndex < 1 || targetIndex >= allWrappers.length) return

    // Collect section elements (header wrapper + cells until next header)
    const sectionElements = this.collectSectionElements(sectionHeader as HTMLElement)

    // Determine insertion point
    const targetWrapper = allWrappers[targetIndex]
    const targetHeader = targetWrapper.querySelector('[data-controller="inline-heading"]')
    if (!targetHeader) return

    if (offset === -1) {
      // Move up: insert before the target section header's wrapper
      sectionElements.forEach(el => {
        this.listTarget.insertBefore(el, targetWrapper)
      })
    } else {
      // Move down: insert after all elements of the target section
      const targetSectionElements = this.collectSectionElements(targetHeader as HTMLElement)
      const lastTargetElement = targetSectionElements[targetSectionElements.length - 1]
      const insertionPoint = lastTargetElement.nextSibling
      sectionElements.forEach(el => {
        this.listTarget.insertBefore(el, insertionPoint)
      })
    }

    // Trigger dirty state
    this.dispatchChange()
  }

  private toggleEmptyState() {
    if (!this.hasEmptyStateTarget) return
    const contentCount = this.listTarget.querySelectorAll(
      '[data-controller="inline-heading"], [data-controller="ruby-cell"], [data-controller="markdown-cell"]',
    ).length
    const hasContent = contentCount > 0
    this.emptyStateTarget.classList.toggle('hidden', hasContent)
  }

  private insertAfterAnchor(fragment: Node, event?: Event): boolean {
    const target = (event?.target as HTMLElement | null) || null
    const anchor = target?.closest(
      '[data-controller="ruby-cell"], [data-controller="markdown-cell"], .mb-4',
    ) as HTMLElement | null
    if (anchor && anchor.parentElement === this.listTarget) {
      anchor.insertAdjacentElement('afterend', document.createElement('div'))
      const spacer = anchor.nextElementSibling as HTMLElement
      if (spacer) {
        spacer.replaceWith(fragment)
      } else {
        this.listTarget.appendChild(fragment)
      }
      return true
    }
    return false
  }

  private collectSectionElements(sectionHeader: HTMLElement): HTMLElement[] {
    const elements: HTMLElement[] = []

    // Include the header's wrapper div
    const headerWrapper = sectionHeader.closest('.mb-4') as HTMLElement
    if (headerWrapper) {
      elements.push(headerWrapper)
    }

    // Collect all following siblings until the next section header wrapper
    let sibling = headerWrapper?.nextElementSibling as HTMLElement | null
    while (sibling) {
      // Stop if we hit another section header
      if (sibling.querySelector('[data-controller="inline-heading"]')) {
        break
      }
      elements.push(sibling)
      sibling = sibling.nextElementSibling as HTMLElement | null
    }

    return elements
  }

  private dispatchChange() {
    const event = new CustomEvent("notebook:cell-changed", {
      bubbles: true,
      detail: { type: "section-reorder" },
    })
    this.element.dispatchEvent(event)
  }
}
