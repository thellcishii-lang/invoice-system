import { Controller } from "@hotwired/stimulus"

// 帳票フォームから離れずに取引先をポップアップで登録し、
// 登録できたら取引先セレクトに追加してそのまま選択する。
// 入力途中の帳票は再読み込みしないので消えない。
export default class extends Controller {
  static targets = ["select", "dialog", "errors", "name", "contactPerson", "email", "phone", "faxNumber", "postalCode", "address"]

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
    const params = new URLSearchParams()
    const fields = {
      name: this.nameTarget,
      contact_person: this.contactPersonTarget,
      email: this.emailTarget,
      phone: this.phoneTarget,
      fax_number: this.faxNumberTarget,
      postal_code: this.postalCodeTarget,
      address: this.addressTarget
    }
    for (const [key, input] of Object.entries(fields)) {
      if (input.value.trim() !== "") params.append(`client[${key}]`, input.value.trim())
    }

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    let response
    try {
      response = await fetch("/clients", {
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
      const client = await response.json()
      const option = new Option(client.name, client.id, true, true)
      this.selectTarget.add(option)
      this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
      for (const input of Object.values(fields)) input.value = ""
      this.close()
    } else {
      const data = await response.json().catch(() => null)
      this.showErrors(data?.errors?.length ? data.errors : ["登録できませんでした。入力内容をご確認ください。"])
    }
  }

  showErrors(messages) {
    this.errorsTarget.textContent = messages.join("／")
    this.errorsTarget.classList.remove("hidden")
  }
}
