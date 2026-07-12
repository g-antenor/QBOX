/*
* This is where you want to add your tips. They **MUST** be in this structure. You can
* have as many or little as you want. In each tooltip object, the `content` value also supports markdown
*
* A list of the markdown supported can be found on the docs
*/
export const LOADSCREEN_TIPS = [
  {
    title: "change-me",
    content: "Welcome to a freshly created **Overextended** server - **change-me**"
  },
  {
    title: "NPWD",
    content: "A fresh server will not have image hosting for NPWD configured automatically, you will need to set this up yourself if you wish to use the camera app [Docs](https://projecterror.dev/docs/npwd/start/installation/#setting-up-camera-functionality)"
  },
  {
    title: "Configuration",
    content: "If you are a developer configuring this server, make sure you update these tips in **/[pe]/pe-basicloading/web/config.js**"
  },
];

// How long a tip is on screen before we automatically
// go to the next one (ms)
export const TIP_CHANGE_INTERVAL = 10000

// How long we stay on a background until we
// go to the next one (ms)
export const BACKGROUND_CHANGE_INTERVAL = 5000

// An array of image files that are available in the `bg` folder
export const BACKGROUND_IMAGES = [
  "1.jpg",
  "2.jpg",
  "3.jpg",
  "4.jpg",
]

// Whether music should be played while loading,
// this will automatically loop the file as well
export const MUSIC_ENABLED = true

// The file name given to your music. This can be
// a .ogg or an .mp3 (MUST BE PRESENT IN `music/` folder)
export const MUSIC_FILE_NAME = 'music.mp3'

export const MUSIC_START_VOLUME = 0.5

// Enable github flavored markdown
export const ENABLE_GFM_MARKDOWN = false

// Enable or disable the included server logo to change this
// logo simply switch the `logo.png` file with the image of your choice
export const ENABLE_SERVER_LOGO = true

// Define server logo placement ['top-left', 'top-right', 'bottom-right', 'center']
export const SERVER_LOGO_POSITION = 'center'

// The name of your logo file within "logo/" directory
export const SERVER_LOGO_FILE_NAME = 'logo.png'