import { Controller } from "@hotwired/stimulus"

// 「一覧に戻る」を押したとき、編集中のものを下書きに保存するか聞く
export default class extends Controller {
  static targets = ["dialog", "afterSave", "draftSubmit"]

  ask(event) {
    this.listUrl = event.currentTarget.dataset.listUrl
    this.dialogTarget.showModal()
  }

  // 「はい」: 下書きとして保存し、保存後は一覧へ戻る
  saveAndLeave() {
    this.afterSaveTarget.value = "list"
    this.dialogTarget.close()
    this.element.closest("form").requestSubmit(this.draftSubmitTarget)
  }

  // 「いいえ」: 保存せずに一覧へ戻る
  discard() {
    this.dialogTarget.close()
    window.location.href = this.listUrl
  }
}
