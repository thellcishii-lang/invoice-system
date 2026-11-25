import { Controller } from "@hotwired/stimulus"

// 明細行の単位をポップアップで追加する。追加した単位はページ内の
// すべての単位セレクトに反映し、押した行ではそのまま選択する。
export default class extends Controller {
  static targets = ["select", "dialog", "errors", "name"]

  open() {
    this.errorsTarget.classList.add("hidden")
    this.dialogTarget.showModal()
    this.nameTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // ポップアップ内の Enter で帳票フォーム自体が送信されないようにする
  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.submit()
    }
  }

  async submit() {
    const name = this.nameTarget.value.trim()
    const params = new URLSearchParams()
    params.append("unit[name]", name)

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    let response
    try {
      response = await fetch("/units", {
        method: "POST",
        headers: {
          "X-CSRF-Token": token,
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: params
      })
    } catch {
      this.showErrors(["通信に失敗しました。もう一度お試しください。"])
      return
    }

    if (response.ok) {
      const unit = await response.json()
      document.querySelectorAll("select[data-unit-select]").forEach((select) => {
        if (![...select.options].some((option) => option.value === unit.name)) {
          select.add(new Option(unit.name, unit.name))
        }
      })
      this.selectTarget.value = unit.name
      this.nameTarget.value = ""
      this.close()
    } else {
      const data = await response.json().catch(() => null)
      this.showErrors(data?.errors?.length ? data.errors : ["追加できませんでした。入力内容をご確認ください。"])
    }
  }

  showErrors(messages) {
    this.errorsTarget.textContent = messages.join("／")
    this.errorsTarget.classList.remove("hidden")
  }
}
