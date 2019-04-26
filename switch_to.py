#!/usr/bin/env python3
# Switch_to.py
# --
# Simple script that allows to jump to between named windows
# --
# by luffah <contact@luffah.xyz>
# --
# Licensed under GPLv3.
# Free as in freedom.
# Free to use. Free to share. Free to modify. Free to verify.
import os
import sys
import time
import tty
import re
import termios
import subprocess
from datetime import datetime
from ewmh import EWMH

logfile = sys.stderr

DEBUG = os.environ.get('DEBUG', True)

def _exec(oscmd):
    return os.popen(oscmd).read().strip()

def logthis(txt, *args):
    if DEBUG:
        print("{0} {1}".format(
            datetime.now(), txt.format(*args)), file=logfile)

class Colors():
    color_tab = {}

    def __get_attr__(self, n):
        return color_tab[n]

    def __set_attr__(self, n, val):
        color_tab[n] = val

    def __init__(self):
        self.grt = _exec('tput setaf 2; tput bold; tput smul')
        self.gre = _exec('tput setf 2; tput bold; tput rmul')
        self.rev = _exec('tput bold; tput rev')
        self.mag = _exec('tput setaf 5')
        self.yel = _exec('tput setaf 3')
        self.yol = _exec('tput setaf 6')
        self.rs = _exec('tput sgr0')

color = Colors()

def _ensure_str(name):
    return '' if not isinstance(name, str) else name

class _EWMH(EWMH):

    def getWmName(self, w):
        # override
        return _ensure_str(w.get_wm_name())

    def getWmClass(self, w):
        # override
        return _ensure_str(w.get_wm_class())

    def getWindowById(self, i):
        ret = [w for w in self.getClientList()
               if w.id == i]
        return ret[0] if ret else None

    def getWindowByNameRe(self, name):

        ret = [w for w in self.getClientList()
               if re.match(name, self.getWmName(w))]

        return ret[0] if ret else None

    def getWindowByName(self, name):
        ret = [w for w in self.getClientList()
               if self.getWmName(w) == name]

        return ret[0] if ret else None

    def getWindowByClassName(self, name):
        ret = [w for w in self.getClientList()
               if self.getWmClass(w) == name]

        return ret[0] if ret else None

    def getWindowByClassNameRe(self, name):
        ret = [w for w in self.getClientList()
               if re.match(name, self.getWmClass(w))]

        return ret[0] if ret else None

    def getWindowByPid(self, pid):
        ret = [w for w in self.getClientList()
               if self.getWmPid(w) == pid]

        return ret[0] if ret else None

    def getWindowFromStr(self, name, re_mode):
        w = self.getWindowByName(name)
        if not w:
            w = self.getWindowByClassName(name)
        if re_mode:
            if not w:
                w = self.getWindowByNameRe(name)
            if not w:
                w = self.getWindowByClassNameRe(name)
        return w

    def showWindowList(self):
        curr = self.getActiveWindow()
        for w in self.getClientList():
            print("%s%-40s %-40s%s" % (
                color.rev if w.id == curr.id else "",
                w.get_wm_name(), w.get_wm_class(),
                color.rs
            ))

def getch():
    fd = sys.stdin.fileno()
    rs = termios.tcgetattr(fd)
    try:
        tty.setraw(sys.stdin.fileno())
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, rs)
    return ch

def prompt():
    sys.stdout.write(
        "{0}\r".format(
            "{0} Press a key to continue or 'q' to quit.{1}".format(
                color.rev, color.rs
            )
        )
    )
    ch = getch()
    sys.stdout.write("${0}\r".format(" "*47))
    if ch == 'q':
        exit(0)

def _translate(s):
    return s.replace(
        ' ','').replace(
            '/','')

def activate_window(name, w):
    if not w:
        return False
    logthis("current_active_wid={0}", current_active_win.id)
    logthis('window_to_activate={0}', w.id)

    last_active_wid_fpath = "/tmp/LAST_%s_WID" % _translate(opt.name)

    if w.id == current_active_win.id:
        try:
            with open(last_active_wid_fpath, 'r') as f:
                last_active_winid = f.read().strip()
        except FileNotFoundError:
            return w

        logthis('last_active_winid={0}', last_active_winid)
        if last_active_winid:
            w = ewmh.getWindowById(int(last_active_winid))
    else:
        with open(last_active_wid_fpath, 'w') as f:
             f.write(str(current_active_win.id))

    if w:
        logthis('window_to_activate={0}', w.id)
        ewmh.setActiveWindow(w)
        ewmh.display.flush()
    return w


def new_window(name, tcmd):
    logthis("Name     : {0}", name)
    logthis("Command  : {0}", " ".join(tcmd))
    env = os.environ.copy()
    env['WINDOW_NAME'] = name
    env['TERM'] = ''
    proc = subprocess.Popen(tcmd or name, env=env)
    if not proc.pid:
        return None
    logthis("PID={0}", proc.pid)
    time.sleep(activation_delay)
    return ewmh.getWindowByPid(proc.pid)

def get_term_open_cmd(name):
    defterm = _exec(
        'readlink /etc/alternatives/x-terminal-emulator | xargs basename'
    )
    all_terms = [t for t in sum([tg[0] for tg in _term_groups.values()], [])]
    if defterm not in all_terms:
        if not _exec(defterm + ' --help 2> /dev/null | grep -- -T'):
            for t in all_terms:
                if _exec('which ' + t):
                    defterm = t
                    break
    for (terms, optformat) in _term_groups.values():
        if defterm in terms:
            opts = [o.format(name) for o in optformat]
    logthis("Using -- {0} {1} --", defterm, " ".join(opts))
    return [defterm] + opts

_term_groups = {
    'st' : (['st', 'stterm'],
            ["-t","{0}","-c","{0}"]),
    'mate': (['lxterminal', 'mate-terminal', 'mate-terminal.wrapper'],
             ["-t","{0}"]),
    '*': (['xterm', 'rxvt', 'xfce4-terminal',
          'xfce4-terminal.wrapper'],
          ["-T" ,"{0}"])
}
default_termname = '.t.%s.'
force_resize = True
switch_to_window = True
ewmh = _EWMH()
current_active_win = ewmh.getActiveWindow()
activation_delay = 1

if __name__ == '__main__':
    def _finalize_opts(opt, args):
        wname = args[0]
        opt.cmd = args[1:]
        if not wname:
            exit(1)
        if opt.termname:
            opt.termmode = True
        if opt.termmode:
            wname = (opt.termname or default_termname) % wname
        opt.re_mode = '.' in wname or '*' in wname
        opt.name = wname

    from optparse import OptionParser
    parser = OptionParser()
    parser.allow_interspersed_args = False
    parser.set_description('Jump between windows')
    parser.set_usage('{0} [option] name [cmd]'.format(sys.argv[0]))
    parser.add_option(
        '-t', '--terminal', action='store_true',
        dest='termmode', default=False,
        help='open a terminal nammed "{1}" ("{0}")'.format(
            default_termname, default_termname % 'name'))
    parser.add_option(
        '-T', '--terminal-name', action='store_const',
        dest='termname', default=None,
        help='open a terminal nammed using a printf like parameter')
    parser.add_option(
        '-l', '--list', action='store_true',
        dest='do_list', default=None,
        help='list windows')
    # parser.add_option('-c','--xbb',action='store_const',const=2,dest='c', default=False)
    (opt, args) = parser.parse_args()
    if opt.do_list:
        ewmh.showWindowList()
        exit()
    _finalize_opts(opt, args)
    window_to_activate = ewmh.getWindowFromStr(opt.name, opt.re_mode)

    if window_to_activate:
        activate_window(opt.name, window_to_activate)
    else:
        if opt.termmode and not opt.cmd:
            opt.cmd = get_term_open_cmd(opt.name)
        new_window(opt.name, opt.cmd)
