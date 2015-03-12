# autopep8-el
autopep8 emacs integration

A day working in [Go](http://golang.org) will cause anyone to miss
`gofmt` severely. [autopep8](https://pypi.python.org/pypi/autopep8/)
provides somewhat similar functionality for python programmers. The
only part missing was integration into the greatest editor of all
time.

## Usage

Install autopep8 somewhere. There is a customization available to
change the path to autopep8 and aggressiveness if need be:

```
M-x customize-group RET autopep8
```

Drop autopep8.el somewhere in your loadpath. Require it and bind
autopep8 to anything you might find useful. I have it bound to `C-c
C-p`:

```
(require 'autopep8)
(defun python-mode-keys ()
  "Modify python-mode local key map"
  (local-set-key (kbd "C-c C-p") 'autopep8))
(add-hook 'python-mode-hook 'python-mode-keys)
```

If you want to autopep8 on save, you'll need to use
`autopep8-before-save` to guard against non-python major modes:

```
(add-hook 'before-save-hook #autopep8-before-save)
```

## Credit

This is an obvious, blatant copy-paste of go-mode.el's gofmt
integration.
