import { Controller } from "@hotwired/stimulus"

// 帳票フォームの明細行の追加・削除と、品目マスタ選択時の明細への反映を行う
export default class extends Controller {
  static targets = ["container", "template"]
  static values = { items: Array }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-line-row]")
    const idField = row.querySelector("input[name$='[id]']")
    const destroyField = row.querySelector("input[name$='[_destroy]']")

    if (idField && idField.value) {
      // 保存済みの行は _destroy を立てて隠す（送信時に削除される）
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }

  itemChanged(event) {
    const item = this.itemsValue.find((entry) => entry.id === Number(event.target.value))
    if (!item) return

    const row = event.target.closest("[data-line-row]")
    row.querySelector("input[name$='[name]']").value = item.name
    row.querySelector("input[name$='[unit_price]']").value = item.unit_price
    const costField = row.querySelector("input[name$='[cost_unit_price]']")
    if (costField) costField.value = item.cost_price ?? ""
    row.querySelector("input[name$='[unit]']").value = item.unit || ""
    row.querySelector("select[name$='[tax_rate]']").value = item.tax_rate
  }
}
