// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
liveSocket.enableDebug()
liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Handle tree updates from LiveView
window.addEventListener("phx:tree-updated", (e) => {
  window.location.reload();
  console.log("Tree updated event received:", e.detail);
  // Force a DOM refresh by temporarily hiding and showing the container
  const container = document.querySelector('[id^="org-chart-container"]');
  if (container) {
    container.style.display = 'none';
    setTimeout(() => {
      container.style.display = 'flex';
    }, 10);
  }
});

// Smooth scroll to a group card by id and highlight a person
window.addEventListener("phx:scroll-to-group", (e) => {
  const { group_id } = e.detail || {}
  const el = document.getElementById(`group-${group_id}`)
  if (!el) return
  el.scrollIntoView({behavior: 'smooth', block: 'center', inline: 'center'})
})

window.addEventListener("phx:highlight-person", (e) => {
  const { person_id } = e.detail || {}
  const el = document.getElementById(`person-${person_id}`)
  if (!el) return
  el.classList.add('ring-4', 'ring-indigo-400', 'ring-offset-2')
  setTimeout(() => {
    el.classList.remove('ring-4', 'ring-indigo-400', 'ring-offset-2')
  }, 2000)
})