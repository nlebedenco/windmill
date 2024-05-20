# How to git good

## Choose the right protocol

Primary differences between SSH and HTTPS. This topic is specifically about
accessing Git repositories on a Server:

**TL;DR: Use SSH**

It is secure and flexible and does not suffer from several of common http
servers restrictions regarding large file transfers and timeouts.

### plain Git, aka `git://<server>/`

- **Does not add security** beyond what Git itself provides. The server is not
  verified.

  If you clone a repository over git://, you should check if the latest commit's
  hash is correct.

- You **cannot push** over it.

### HTTPS, aka `https://<server>/`

- HTTPS **will always verify the server** automatically, using certificate
  authorities.

- (On the other hand, in the past years several certificate authorities have
  been broken into, and many people consider them not secure enough. Also, some
  important HTTPS security enhancements are only available in web browsers, but
  not in Git.)

- Uses **password** authentication for pushing, and still allows anonymous pull.

- Downside: You have to enter your Server password every time you
  push. [Git can remember passwords][2] for a few minutes, but you need to be
  careful when storing the password permanently – since it can be used to change
  anything in your Server account.

- If you have two-factor authentication enabled, you will have to use
  a [personal access token][3] instead of your regular password.

- HTTPS **works practically everywhere**, even in places which block SSH and
  plain-Git protocols. In some cases, it can even be **a little faster** than
  SSH, especially over high-latency connections.

### HTTP, aka `http://<server>/`

- Doesn't work with some services anymore like Github, but is offered by some
  other Git hosts.

- Works practically everywhere, like HTTPS.

- But does not provide any security – the connection is plain-text.

### SSH, aka `git@<server>:` or `ssh://git@<server>/`

- Uses **public-key** authentication. You have to [generate a **keypair**][1] (
  or "public key"), then add it to your server account.

- Using keys is **more secure than passwords**, since you can add many to the
  same account (for example, a key for every computer you use Git from). The
  private keys on your computer can be protected with passphrases.

- On the other hand, since you do not use the password, the Server does not
  require two-factor auth codes either – so whoever obtains your private key can
  push to your repositories without needing the code generator device.

- However, the keys only allow pushing/pulling, but _not_ editing account
  details. If you lose the private key (or if it gets stolen), you can just
  remove it from your Server account.

- A minor downside is that authentication is needed for all connections, so you
  always **need a Server account** – even to pull or clone.

- You also need to **carefully verify the server's fingerprint** when connecting
  for the first time. Many people skip that and just type "yes", which is
  insecure.

## Set up git on Windows

You will need to download and install the following tools:

1. [Git for Windows](https://git-scm.com/download/win) version >= 2.45.0
   (64-bit recommended)

2. [TortoiseGit](https://tortoisegit.org/download/) version >= 2.16
   (64-bit recommended)

Git 2.45 can install git-lfs too so there is no need to download a separate
installer for that.

Start by installing Git.

- Path
  ![Git Screen 1](01.jpg)

- Options
  ![Git Screen 2](02.jpg)

    - Additional icons and windows explorer integration are left out because we
      are
      going to use Tortoise for that.

    - Adding a Git Bash profile to Windows Terminal is optional but not very
      useful
      unless you are an experienced developer and plans to use shell scripts on
      Windows (not recommended for beginners).

    - Adding the new `Scalar` tool at the bottom of the list is optional (not
      showing
      in the screenshot).

- Default editor
  ![Git Screen 3](03.jpg)

    - Select default editor. Notepad is recommended as it is simple, fast and
      more
      user friendly than Vim. Notepad++ is another good alternative but has been
      known to have broken git integration in the past.
      See https://stackoverflow.com/q/63529351

- Default main branch name
  ![Git Screen 4](04.jpg)

    - Select the default branch name. Any name will do really. One can always
      change the default branch later. Let git decide is the recommended
      approach
      because it offers better compatibility and less friction unless your are
      particularly sensitive to the word "master" in which case therapy is also
      recommended.

- Adjusting your PATH environment
  ![Git Screen 5](05.jpg)

- Choosing SSH executable
  ![Git Screen 6](06.jpg)

    - Bundled OpenSSH is the recommended option because it is the more flexible
      one for experienced users. Tortoise Plink configuration is shown in the
      Tortoise installation steps.

- Which SSL/TLS library to use for HTTPS
  ![Git Screen 7](07.jpg)

- Default EOL conversion
  ![Git Screen 8](08.jpg)

- Terminal emulator to use with git-bash
  ![Git Screen 9](09.jpg)

    - Windows console is recommended to avoid surprising behaviour when commands
      and/or scripts are invoked from the Windows console (e.g. UTF-8 characters
      not
      printed correctly).

- Default `git pull`  behaviour
  ![Git Screen 10](10.jpg)

    - Fetch and merge is the most user-friendly option for beginners.

- Use Git credential
  ![Git Screen 11](11.jpg)

- Enable file system caching and disable symlinks
  ![Git Screen 12](12.jpg)

- Experimental features
  ![Git Screen 13](13.jpg)

Once the installation is complete, open a console window and check git and
git-lfs versions. For example:

  ```
  C:\>git --version
  git version 2.45.1.windows.1

  C:\>git-lfs --version
  git-lfs/3.5.1 (GitHub; windows amd64; go 1.21.7; git e237bb3a)
  ```

Now install and configure TortoiseGit as follows:

- Tortoise Options
  ![Tortoise Screen 1](tortoise/01.jpg)

- Complete the installtion and run the "First use Wizard"

- Authentication and credential store
  ![Tortoise Screen 2](tortoise/02.jpg)

    - Click in "Generate PuTTY key pair"

    - PuTTY Key Generator will open as shown below:
      ![Tortoise Screen 3](tortoise/03.jpg)

    - Click in "Generate"

        - If you skipped the first use wizard, this step can be repeated by
          executing the key generator directly from
          `C:\Program Files\TortoiseGit\bin\puttygen.exe`

    - Move the mouse cursor erratically over the window to generate random input
      for the key until the progress bar is filled.

    - Save the keys
      ![Tortoise Screen 4](tortoise/04.jpg)

        1. The key comment is optional and can hold whatever value. Write
           something
           you can use to identify your key later.

        2. You are encouraged to define a passphrase to secure your keys but you
           may
           choose not to do so for example when already using an encrypted
           volume to
           store the keys.

        3. Click on "Save Public Key"

        4. Save your public key in a secure location. Use the extension *.pub
           If you decided not to use a passphrase, you can ignore the warning
           about
           it.

        5. Click on "Save Private Key"

        6. Save your public key in a secure location. Use the extension *.ppk
           If you decided not to use a passphrase, you can ignore the warning
           about
           it.

        7. In the main menu click `Conversions -> Export OpenSSH key`
           Save your RSA pub key in a secure location. Use the extension *.rsa

        8. Copy the contents of the text box "Public key for pasting into
           OpenSSH
           authorized_keys file". This is the same key saved in your *.pub
           file .

        9. Click "Finish"

- Make sure you have the `GIT_SSH` environment variable pointing to
  TortoiseGitPlink. For example:
  ![Tortoise Screen 5](tortoise/05.jpg)

TortoiseGitPlink C:\Program Files\TortoiseGit\bin\TortoiseGitPlink.exe

Configure your public key in your git server:

- [Bitbucket](bitbucket/access-keys.md)

- [Github](github/access-keys.md)

- [GitLab](gitlab/access-keys.md)

Create a Pageant Shortcut

1. Despite TortoiseGit having a feature to load your key automatically upon
   first execution we are going to setup a shotcut to manually execute Pageant
   on Windows startup so we can seamlessly use TortoiseGit AND the git client on
   the command prompt without having to worry about key loading.

2. Right-click on the desktop. Select New -> Shortcut

3. In the target type:
   `"C:\Program Files\TortoiseGit\bin\pageant.exe" <filename>.ppk`
   replacing filename for the name you used to save your private key in the
   previous step.

4. Double-click the shortcut to make sure the key file can be successfully
   loaded.

5. In order to have windows load the key on start up simply copy and paste this
   shortcut in %AppData%\Microsoft\Windows\Start Menu\Programs\Startup

Quickly find your .gitconfig files

1. Right-click on the Desktop
2. Select `TortoiseGit -> Settings`
3. In the tree view on the left side of the window select Git.
4. Select Global (user) or System settings and fill in the necessary
   information.

## Set up git on Linux

TODO

## Set up git on macOS

TODO

## Example user .gitconfig

```
[core]
	autocrlf = true
	safecrlf = true
	filemode = false
	longpaths = true
[user]
	name = <your user name here>
	email = <your email here>
[credential]
	helper = manager-core
[color]
	ui = true
	branch = auto
	diff = auto
	interactive = auto
	status = auto
[alias]
	st = status -s
	lg = log --color --graph --no-abbrev-commit --decorate
[push]
	default = matching
[pull]
	rebase = false
[diff]
	submodule = log
	algorithm = patience
[diff "json"]
	textconv = python -m json.tool
```
