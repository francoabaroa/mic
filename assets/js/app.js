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

Hooks.CommentsChart = {
  mounted() {
    var ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ['January', 'February', 'March', 'April', 'May', 'June', 'July'],
        datasets: [
          {
            label: 'Comments',
            backgroundColor: 'rgba(75, 192, 192, 0.2)',
            borderColor: 'rgba(75, 192, 192, 1)',
            data: [0, 14, 15, 22, 26, 36, 45]
          }
        ]
      },
      options: {}
    });
    this.handleEvent("comments", ({ comments }) => {
      this.chart.data.datasets[0].data = comments;
      this.chart.update();
    });
  }
}

Hooks.ListenersChart = {
  mounted() {
    var ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ['January', 'February', 'March', 'April', 'May', 'June', 'July'],
        datasets: [
          {
            label: 'Listeners',
            backgroundColor: 'rgba(255, 99, 132, 0.2)',
            borderColor: 'rgba(255, 99, 132, 1)',
            data: [0, 13, 7, 3, 25, 29, 45]
          }
        ]
      },
      options: {}
    });
    this.handleEvent("listeners", ({ listeners }) => {
      this.chart.data.datasets[0].data = listeners;
      this.chart.update();
    });
  }
}

Hooks.LikesChart = {
  mounted() {
    var ctx = this.el.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ['January', 'February', 'March', 'April', 'May', 'June', 'July'],
        datasets: [
          {
            label: 'Likes',
            backgroundColor: 'rgba(54, 162, 235, 0.2)',
            borderColor: 'rgba(54, 162, 235, 1)',
            data: [0, 10, 5, 2, 20, 30, 45]
          },
        ]
      },
      options: {}
    });
    this.handleEvent("likes", ({ likes }) => {
      this.chart.data.datasets[0].data = likes;
      this.chart.update();
    });
  }
}

Hooks.VoiceAudioHandlers = {
  mounted() {
    this.handleEvent("audio_chunk", ({ chunk }) => {
      // Object to keep track of processed chunks
      const processedChunks = {};

      // Decode the base64 chunk and play the audio
      function base64ToBlob(base64, mimeType) {
        let byteCharacters = atob(base64);
        let byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
          byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        let byteArray = new Uint8Array(byteNumbers);
        return new Blob([byteArray], { type: mimeType });
      }

      // Check if the chunk has already been processed
      if (!processedChunks[chunk]) {
        let audioBlob = base64ToBlob(chunk, 'audio/mpeg');
        processedChunks[chunk] = true;
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
      }
    });

    let mediaRecorder;
    let audioChunks = [];

    this.handleEvent("start_recording", ({ record }) => {
      navigator.mediaDevices.getUserMedia({ audio: true })
        .then(stream => {
          mediaRecorder = new MediaRecorder(stream);
          mediaRecorder.start();

          mediaRecorder.addEventListener("dataavailable", event => {
            audioChunks.push(event.data);
          });

          mediaRecorder.addEventListener("stop", () => {
            const audioBlob = new Blob(audioChunks);
            const reader = new FileReader();
            reader.readAsDataURL(audioBlob);
            reader.onloadend = () => {
              const base64AudioMessage = reader.result.split(',')[1];
              this.pushEvent("transcribe_voice", { audio: base64AudioMessage });
            };
          });
        });
    });

    this.handleEvent("stop_recording", () => {
      audioChunks = [];
      mediaRecorder.stop();
    });
  }
};

let collapsibleList = document.getElementsByClassName("collapsible-list");
for (let i = 0; i < collapsibleList.length; i++) {
  collapsibleList[i].addEventListener("click", function () {
    this.classList.toggle("active");
    let content = this.nextElementSibling;
    if (content.style.display === "block") {
      content.style.display = "none";
    } else {
      content.style.display = "block";
    }
  });
}

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

