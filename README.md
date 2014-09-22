AHK Automate
============

This is a AutoHotkey script providing some nifty features for overall automation on Windows machines.


This script is somewhat personalized and may not work on the first run, however
one thing to do is to set your textEditor = C:\Program Files\Sublime Text 2\sublime_text.exe
to something more appropriate to your preferences near line 1242.

The most useful features for me so far are:

* Changing volume by scrolling at either left or right end of the screen (I personally disabled the left side on my version)

* Using the quick notes editor via Context Menu button most keyboards have

* The "screen off" command

* Automatic conversion of e.g. \epsilon to ε

* "learnas {new command alias}" for quick opening of files/folders/urls without the need for shortcuts


**To start typing in a command, hold down Caps Lock and type one of the following basic commands with {parameters options}, [optional params]:**

* Soft screen turn off:
    * screen {on | off}


* Sleep:
    * sleep


* Lock:
    * lock


* Toggle caps lock (can also be done via Shift + Caps Lock):
    * caps


* Switch to window that starts with title (can be partial):
    * s {title}


* Maximize current window:
    * \+


* Minimize current window:
    * \-


* Close current window:
    * x


* Learn to open currently selected file, folder or URL (try it out!):
    * learnas {command alias}


* Unlearn the above:
    * unlearn {command alias}


* Opens either the current running script, the added config file (basically a database for saving preferences)
or the hosts file up for editing in your favourite editor:
    * edit {script | config | hosts}


* Shows the usage of commands so far:
    * cmds


* Inputs keystrokes to currently active caret (anyhere) in one bunch:
    * send {text}


* "About" page:
    * about


* Date:
    * date [{copy | put}]


* Wordcount of text in clipboard (that is with Ctrl + C or similar):
    * wordcount


* Shows IP (by default public):
    * ip [local] [{copy | put}]


* Shows current song playing in Winamp:
    * song [{copy | put}]


* Alarm timer:
    * timer {time_length | off}


* Opens up 2 notes windows (also opanable via context menu button next to Alt Gr):
    * notes


## Varia

Type these anywhere (except LyX and command window) and get the converted symbol (:: is the separator in code):


maths:
* ---::—
* +-::±
* ~=::≈

greeks:
* \alpha::α
* \beta::β
* \gamma::γ
* \delta::δ
* \Delta::Δ
* \epsilon::ε
* \zeta::ζ
* \eta::η
* \theta::θ
* \Theta::Θ
* \lambda::λ
* \mu::μ
* \nu::ν
* \pi::π
* \Pi::Π
* \rho::ρ
* \tau::τ
* \phi::φ
* \Phi::Φ
* \omega::ω
* \Omega::Ω


smileys without emoticons:
* .P:::Ρ
* .p:::р
* .o:::ο
* .9:::﴿
* .8:::﴾
* .d:::ԁ
* .D:::D

## Also

* Pause and Scroll Lock are remapped to Home and End

* Alt + a is å

* Alt + A is Å

* Alt + o is °

* Alt + . is ·

* Cursor at either side of the screen and scrolling changes the system volume

* Shift + Caps Lock is old Caps Lock

* The button next to 1 (not 2) disables Authotkey script until enabled again via Caps Lock

* Button next to Alt Gr AKA Context Menu opens up the quick notes editor, inside the editor

* you can use Ctrl + Arrows to control the side you are writing on and the font size.

* Typing any non-existing command is tried to evaluate on cmd.exe



