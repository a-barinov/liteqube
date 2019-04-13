#!/usr/bin/python3


import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GObject
import os


def LOG(text):
    os.system('echo "%s"'%str(text))


class WifiMonitor:

    NM = 'org.freedesktop.NetworkManager'

    enabled = -1
    state = -1
    ssid = '------'
    ap = ''

    def __init__(self):
        self.bus = dbus.SystemBus()
        nm = self.bus.get_object(self.NM, '/org/freedesktop/NetworkManager')
        enabled = nm.Get(self.NM, 'WirelessEnabled', dbus_interface = dbus.PROPERTIES_IFACE)
        if enabled != 1:
            self.update(enabled, self.state, self.ssid)
        else:
            for device in map(lambda d: self.bus.get_object(self.NM, d), nm.GetDevices(dbus_interface = self.NM)):
                if device.Get(self.NM+'.Device', 'DeviceType', dbus_interface = dbus.PROPERTIES_IFACE) == 2:
                    state = device.Get(self.NM+'.Device', 'State', dbus_interface = dbus.PROPERTIES_IFACE)
                    accesspoint = device.Get(self.NM+'.Device.Wireless', 'ActiveAccessPoint', dbus_interface = dbus.PROPERTIES_IFACE)
                    self.update(enabled, state, self.get_ssid(accesspoint))
                    break
        self.bus.add_signal_receiver(self.dbus_enabled, 'PropertiesChanged', self.NM, None, None)
        self.bus.add_signal_receiver(self.dbus_state, 'PropertiesChanged', self.NM+'.Device.Wireless', None, None)
        self.bus.add_signal_receiver(self.dbus_signal, 'PropertiesChanged', self.NM+'.AccessPoint', None, None)

    def get_ssid(self, accesspoint_name):
        if accesspoint_name == '/':
            return ''
        else:
            accesspoint = self.bus.get_object(self.NM, accesspoint_name)
            return bytearray(accesspoint.Get(self.NM+'.AccessPoint', 'Ssid', dbus_interface = dbus.PROPERTIES_IFACE)).decode()

    def dbus_enabled(self, args):
        #LOG('\nENABLED')
        #LOG(args)
        if 'WirelessEnabled' in args:
            self.update(args['WirelessEnabled'], self.state, self.ssid)

    def dbus_state(self, args):
        #LOG('\nSTATE')
        #LOG(args)
        if 'ActiveAccessPoint' in args:
            self.update(self.enabled, self.state, self.get_ssid(args['ActiveAccessPoint']))
            self.ap = args['ActiveAccessPoint']
        if 'State' in args:
            self.update(self.enabled, args['State'], self.ssid)

    def dbus_signal(self, args):
        #LOG('\nSIGNAL')
        #LOG(args)
        if 'Strength' in args and not 'LastSeen' in args:
            strength = args['Strength']
            if strength > 100:
                strength = 100
            nm = self.bus.get_object(self.NM, '/org/freedesktop/NetworkManager')
            for device in map(lambda d: self.bus.get_object(self.NM, d), nm.GetDevices(dbus_interface = self.NM)):
                if device.Get(self.NM+'.Device', 'DeviceType', dbus_interface = dbus.PROPERTIES_IFACE) == 2:
                    accesspoint = device.Get(self.NM+'.Device.Wireless', 'ActiveAccessPoint', dbus_interface = dbus.PROPERTIES_IFACE)
                    self.update(self.enabled, self.state, self.get_ssid(accesspoint))
                    break
            os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalWifi+SI-%d 1>/dev/null 2>&1'%strength)

    def update(self, enabled, state, ssid):
        if self.ssid != ssid:
            sanitized = ''.join([c if c.isalnum() else '_' for c in ssid])
            if sanitized == '':
                os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalWifi+AP- 1>/dev/null 2>&1')
            else:
                os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalWifi+AP-%s 1>/dev/null 2>&1'%sanitized)
        if self.enabled != enabled:
            os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalWifi+EN-%d 1>/dev/null 2>&1'%enabled)
        if self.state != state:
            os.system('/usr/bin/qrexec-client-vm dom0 alte.SignalWifi+ST-%d 1>/dev/null 2>&1'%state)
        self.enabled = enabled
        self.state = state
        self.ssid = ssid


if __name__ == '__main__':
    DBusGMainLoop(set_as_default = True)
    GObject.threads_init()
    WifiMonitor()
    GObject.MainLoop().run()
