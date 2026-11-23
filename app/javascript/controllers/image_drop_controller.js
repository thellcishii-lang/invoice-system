import { Controller } from "@hotwired/stimulus"

// 画像のドラッグ＆ドロップ＋プレビュー。ファイルは通常のフォーム送信で送られる
// （input にファイルをセットするだけ）。
export default class extends Controller {
  static targets = ["input", "preview", "zone"]

  open() {
    this.inputTarget.click()
  }

  picked() {
    if (this.inputTarget.files.length > 0) this.show(this.inputTarget.files[0])
  }

  dragOver(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("border-blue-500", "bg-blue-50")
  }

  dragLeave(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("border-blue-500", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("border-blue-500", "bg-blue-50")
    const file = event.dataTransfer.files[0]
    if (!file) return
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.show(file)
  }

  show(file) {
    if (!/^image\/(png|jpeg)$/.test(file.type)) return
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.src = e.target.result
      this.previewTarget.classList.remove("hidden")
    }
    reader.readAsDataURL(file)
  }
}
