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
let sourceNode = null;
let bufferQueue = [];

function fetchAndDecodeAudio(base64Data) {
  let byteCharacters = atob(base64Data);
  let byteNumbers = new Array(byteCharacters.length);
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  let byteArray = new Uint8Array(byteNumbers);
  let blob = new Blob([byteArray], { type: 'audio/mpeg' });
  let url = URL.createObjectURL(blob);

  fetch(url)
    .then(response => {
      return response.arrayBuffer();
    })
    .then(arrayBuffer => {
      return audioContext.decodeAudioData(arrayBuffer);
    })
    .then(audioBuffer => {
      bufferQueue.push(audioBuffer);
      if (!sourceNode || sourceNode.buffer === null) {
        playBuffer();
      }
    })
    .catch(err => console.error('Error with decoding audio:', err));
}

function playBuffer() {
  if (bufferQueue.length > 0 && (sourceNode == null || sourceNode.buffer == null)) {
    sourceNode = audioContext.createBufferSource();
    sourceNode.buffer = bufferQueue.shift();
    sourceNode.connect(audioContext.destination);
    sourceNode.start();
    sourceNode.onended = function () {
      sourceNode = null; // Reset the sourceNode to null after playback
      playBuffer(); // Try to play the next buffer in the queue
    };
  }
}

function scrollToLastChatBubble() {
  let chatBubbles = document.querySelectorAll(".chat");
  let lastChatBubble = chatBubbles[chatBubbles.length - 1];
  if (lastChatBubble) {
    lastChatBubble.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function initAudio() {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
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
      options: {
        plugins: {
          legend: {
            labels: {
              color: 'white'
            }
          }
        },
        scales: {
          x: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          },
          y: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          }
        },
      }
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
      options: {
        plugins: {
          legend: {
            labels: {
              color: 'white'
            }
          }
        },
        scales: {
          x: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          },
          y: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          }
        }
      }
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
      options: {
        plugins: {
          legend: {
            labels: {
              color: 'white'
            }
          }
        },
        scales: {
          x: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          },
          y: {
            ticks: { color: 'white' },
            grid: { color: 'rgba(255, 255, 255, 0.1)' }
          }
        }
      }
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

      // Check if the chunk has already been processed
      if (!processedChunks[chunk]) {
        processedChunks[chunk] = true;
        fetchAndDecodeAudio(chunk);
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

document.addEventListener('click', initAudio);

window.addEventListener(`phx:newmessage`, (e) => {
  console.log("new message");
  scrollToLastChatBubble();
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