# Overview

I run [Volumio](https://volumio.org/) on several Raspberry Pi's in my home. This code will provision them to accept bluetooth connections and allow me to pair a phone and stream audio to them. Volumio offers this feature, but only if you pay $35+ per year for a single RPi.

I summarize here the modifications to do to enable bluetooth support, youtube chrome cast support and spotify connect.

## Hardware

- raspberry pi 2, 3 or 4 (be careful with the bluetooth and wifi [bug](https://github.com/raspberrypi/linux/issues/1552) on RPI3)
- [Innomaker HIFI AMP HAT](https://www.inno-maker.com/product/hifi-amp-hat/) and its [user manual](pdf/HIFI-AMP-HAT-User-Manual-V1.2.pdf)
- a set of old sony speaker

## Step 0: Volumio version and plugin

- [Volumio 2.915 (30-09-2021)](https://community.volumio.org/t/volumio-changelog/1446)
-Plugins: 
  - **Spotify** (include in the list of available plugins)
  - **Spotify connect 2** (include in the list of available plugins)
  - **Podcast** (include in the list of available plugins)
  - [**Youtube2 plugin**](https://github.com/patrickkfkan/volumio-youtube2)
  - [**YouTube Cast Receiver for Volumio**](https://github.com/patrickkfkan/volumio-ytcr)

## Step 1: Revert from hybrid Stretch/Jessie Volumio images back to pristine Jessie

In the version of volumio 2.915, there is a mix of packages from Jessie and Stretch. 
To Revert from hybrid Stretch/Jessie Volumio images back to pristine Jessie, you can use the [following script](script/backToJessie.sh). (It comes from [here](https://gist.githubusercontent.com/ashthespy/b01c5a57570364971553ce34d77f11b6/raw/acd81fdb3e9fd5024ec515fd612fc0106efb2919/backToJessie.sh) and [this discussion](https://community.volumio.org/t/cannot-install-build-essential-package/46856/31))

```bash
curl -fsSLO "https://gist.githubusercontent.com/ashthespy/b01c5a57570364971553ce34d77f11b6/raw/acd81fdb3e9fd5024ec515fd612fc0106efb2919/backToJessie.sh"
chmod +x backToJessie.sh && sudo ./backToJessie.sh
```

Next you can install the *build-essential* package

```bash
sudo apt install build-essential
```

## Step 2: Install Bluez and bluealsa and other small stuffs

This step comes from this [repo](https://github.com/pgporada/ansible-playbook-volumio-bluetooth)

### Step 2.1: play the ansible playbook to install Bluez and BlueAlsa

```bash
    # Temporarily enable ssh mode at http://volumio_ip/dev

    # On your own computer, not necessarily the raspberry pi, you can run
    sudo apt install ansible git sshpass

    # Get this repository onto your computer
    cd ansible-playbook-volumio-bluetooth

    # Configure the Volumio server IP so that you're connecting to the correct device
    cd ansible-playbook-volumio-bluetooth
    nano -w hosts.example

    # Run ansible from your computer to configure the Volumio server
    ansible-playbook playbook.yml -i hosts.example -kK

```

This playbook install:
- BlueZ (compile and install) and bluealsa (compile and install)
- bluealsa-aplay@.service
- udev rules 99-input.rules
- a2dp-autoconnect.sh script in /home/volumio/

### Step 2.2: clean the installation

Next remove *99-input.rules* in */etc/udev/rules/99-input.rules*

```bash
# connect to your volumio through ssh and then 
sudo rm /etc/udev/rules/99-input.rules
sudo rm /home/volumio/a2dp-autoconnect.sh
```

### Step 2.3: Disabling Integrated Bluetooth (Optional)

If you are using a separate USB Bluetooth dongle, disable the integrated Bluetooth to prevent conflicts.

To disable the integrated Bluetooth add the following

```bash
# Disable onboard Bluetooth
dtoverlay=pi3-disable-bt
```

to /boot/config.txt and execute the following command

```bash
sudo systemctl disable hciuart.service
```

### Step 2.4: Make Bluetooth Discoverable

Normally a Bluetooth device is only discoverable for a limited amount of time. Since this is a headless setup we want the device to always be discoverable.

Set the DiscoverableTimeout in */etc/bluetooth/main.conf* to 0

```bash
# How long to stay in discoverable mode before going back to non-discoverable
# The value is in seconds. Default is 180, i.e. 3 minutes.
# 0 = disable timer, i.e. stay discoverable forever
DiscoverableTimeout = 0
PairableTimeout = 0
AutoConnectTimeout = 0
```

**Enable discovery on the Bluetooth controller**

```bash
sudo bluetoothctl
power on
discoverable on
exit
```

### Step 2.5: Install The A2DP Bluetooth Agent

A Bluetooth agent is a piece of software that handles pairing and authorization of Bluetooth devices. The following agent allows the Raspberry Pi to automatically pair and accept A2DP connections from Bluetooth devices.
All other Bluetooth services are rejected.

Copy the included file **script/a2dp-agent** to `/usr/local/bin` and make the file executable with

```bash
sudo cp script/a2dp-agent /usr/local/bin/ && sudo chmod +x /usr/local/bin/a2dp-agent
```

### Step 2.6: Testing the agent

Before continuing, verify that the agent is functional. The Raspberry Pi should be discoverable, pairable and recognized as an audio device.

Note: At this point the device will not output any audio. This step is only to verify the Bluetooth is discoverable and bindable.

1. Manually run the agent by executing
```
sudo /usr/local/bin/a2dp-agent
```
2. Attempt to pair and connect with the Raspberry Pi using your phone or computer.
3. The agent should output the accepted and rejected Bluetooth UUIDs
```
A2DP Agent Registered
AuthorizeService (/org/bluez/hci0/dev_94_01_C2_47_01_AA, 0000111E-0000-1000-8000-00805F9B34FB)
Rejecting non-A2DP Service
AuthorizeService (/org/bluez/hci0/dev_94_01_C2_47_01_AA, 0000110d-0000-1000-8000-00805f9b34fb)
Authorized A2DP Service
AuthorizeService (/org/bluez/hci0/dev_94_01_C2_47_01_AA, 0000111E-0000-1000-8000-00805F9B34FB)
Rejecting non-A2DP Service
```

### Step 2.7: Install the A2DP Bluetooth agent as a service

To make the A2DP Bluetooth Agent run on boot copy the included file **bt-agent-a2dp.service** to `/etc/systemd/system`.
Now run the following command to enable the A2DP Agent service
```
cd /etc/systemd/system
sudo cp script/bt-agent-a2dp.service .
sudo systemctl enable bt-agent-a2dp.service
sudo systemctl start bt-agent-a2dp.service
```

Bluetooth devices should now be able to discover, pair and connect to the Raspberry Pi without any user intervention.

### Step 2.8: Testing audio playback

Now that Bluetooth devices can pair and connect with the Raspberry Pi we can test the audio playback.

The tool `bluealsa-aplay` is used to forward audio from the Bluetooth device to the ALSA output device (sound card).

find your card output:

```
aplay -L
```


Execute the following command to accept A2DP audio from any connected Bluetooth device.

```bash
# sndrpihifiberry should be replace 
bluealsa-aplay -vv 00:00:00:00:00:00 -D hw:CARD=sndrpihifiberry
```

Play a song on the Bluetooth device and the Raspberry Pi should output audio on either the headphone jack or the HDMI port. See [this guide](https://www.raspberrypi.org/documentation/configuration/audio-config.md) for configuring the audio output device of the Raspberry Pi.

### Step 2.9: Install the audio playback as a service

To make the audio playback run on boot copy the included file **a2dp-playback.service** to `/etc/systemd/system`.
Now run the following command to enable A2DP Playback service

```bash
cd /etc/systemd/system
sudo cp script/a2dp-playback.service .
# edit the a2dp a2dp-playback.service (line 8 to send the sound to the correct output)
sudo systemctl enable a2dp-playback.service
sudo systemctl start a2dp-playback.service
```

Reboot and enjoy!


# References

Much of this comes from manual steps found here:
- https://forum.volumio.org/volumio-bluetooth-receiver-t8937.html
- https://www.raspberrypi.org/forums/viewtopic.php?f=38&t=247892
- https://community.volumio.org/t/cannot-install-build-essential-package/46856/31
- https://community.volumio.org/t/cannot-install-build-essential-package/46856/31
- https://github.com/pgporada/ansible-playbook-volumio-bluetooth
- https://gist.github.com/mill1000/74c7473ee3b4a5b13f6325e9994ff84c#file-a2dp-agent
- https://community.volumio.org/t/guide-volumio-bluetooth-receiver/7859/52
