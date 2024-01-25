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
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let audioContext = new AudioContext();
let mediaSource = new MediaSource();
let sourceBuffer;
let queue = [];
let audioInitialized = false;

mediaSource.addEventListener('sourceopen', () => {
  sourceBuffer = mediaSource.addSourceBuffer('audio/mpeg');
  sourceBuffer.addEventListener('updateend', () => {
    if (queue.length > 0 && !sourceBuffer.updating) {
      sourceBuffer.appendBuffer(queue.shift());
    }
  });
});

let audio = new Audio();
audio.src = URL.createObjectURL(mediaSource);

function initAndPlayAudio() {
  if (audioContext.state === 'suspended') {
    audioContext.resume().then(() => {
      // TODO: remove
      console.log('Playback resumed successfully');
      audio.play();
    });
  } else {
    audio.play();
  }
}

let Hooks = {};

Hooks.AuthRedirects = {
  mounted() {
    this.handleEvent("redirect_to_spotify", ({ url }) => {
      window.location = url;
    });
    this.handleEvent("redirect_to_instagram", ({ url }) => {
      window.location = url;
    });
  }
};

Hooks.AudioHandler = {
  mounted() {
    this.handleEvent("audio_chunk", ({ chunk }) => {
      // // Decode the base64 chunk and play the audio
      function base64ToBlob(base64, mimeType) {
        let byteCharacters = atob(base64);
        let byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        let byteArray = new Uint8Array(byteNumbers);
        return new Blob([byteArray], { type: mimeType });
      }

      let audioBlob = base64ToBlob(chunk, 'audio/mpeg');
      let reader = new FileReader();
      reader.onload = function () {
        let arrayBuffer = this.result;
        if (!sourceBuffer.updating && queue.length === 0) {
          sourceBuffer.appendBuffer(arrayBuffer);
        } else {
          queue.push(arrayBuffer);
        }
      };
      reader.readAsArrayBuffer(audioBlob);
    });
  }
};

// TODO: What is the correct fix for this?
document.addEventListener('click', function () {
  if (!audioInitialized) {
    initAndPlayAudio();
    audioInitialized = true;
  }
});

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

