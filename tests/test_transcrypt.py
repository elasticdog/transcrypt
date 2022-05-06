"""
Requirements:
    pip install gpg_lite
    pip install ubelt
"""
import ubelt as ub
import os

SALTED = 'U2FsdGV'


class TranscryptAPI:
    default_config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'use_pbkdf2': '0',
        'salt_method': 'password',
        'config_salt': '',
    }

    def __init__(self, dpath, config=None, verbose=2, transcript_exe=None):
        self.dpath = dpath
        self.verbose = verbose
        self.transcript_exe = ub.Path(ub.find_exe('transcrypt'))
        self.env = {}
        self.config = self.default_config.copy()
        if config:
            self.config.update(config)

    def cmd(self, command, shell=False):
        return ub.cmd(command, cwd=self.dpath, verbose=self.verbose,
                      env=self.env, shell=shell)

    def login(self):
        command = (
            "{transcript_exe} -c '{cipher}' -p '{password}' "
            "-md '{digest}' --use-pbkdf2 '{use_pbkdf2}' "
            "-sm '{salt_method}' "
            "-cs '{config_salt}' "
            "-y"
        ).format(transcript_exe=self.transcript_exe, **self.config)
        self.cmd(command)

    def logout(self):
        self.cmd(f'{self.transcript_exe} -f -y')

    def display(self):
        self.cmd(f'{self.transcript_exe} -d')

    def export_gpg(self, recipient):
        self.cmd(f'{self.transcript_exe} --export-gpg "{recipient}"')
        self.crypt_dpath = self.cmd('git config --local transcrypt.crypt-dir')['out'] or self.dpath / '.git/crypt'
        asc_fpath = (self.crypt_dpath / (recipient + '.asc'))
        return asc_fpath

    def import_gpg(self, asc_fpath):
        command = f"{self.transcript_exe} --import-gpg '{asc_fpath}' -y"
        self.cmd(command)

    def show_raw(self, fpath):
        return self.cmd(f'{self.transcript_exe} -s {fpath}')['out']

    def _manual_hack_info(self):
        """
        Info on how to get an env to run a failing command manually
        """
        for k, v in self.env.items():
            print(f'export {k}={v}')
        print(f'cd {self.dpath}')


class TestEnvironment:

    def __init__(self, dpath=None, config=None, verbose=2):
        if dpath is None:
            # import tempfile
            # self._tmpdir = tempfile.TemporaryDirectory()
            # dpath = self._tmpdir.name
            dpath = ub.Path.appdir('transcrypt/tests/test_env')
        self.dpath = ub.Path(dpath)
        self.gpg_store = None
        self.repo_dpath = None
        self.verbose = verbose
        self.tc = None
        self.config = config

    def setup(self):
        self._setup_gpg()
        self._setup_git()
        self._setup_transcrypt()
        return self

    def _setup_gpg(self):
        import gpg_lite
        self.gpg_home = (self.dpath / 'gpg').ensuredir()
        self.gpg_store = gpg_lite.GPGStore(
            gnupg_home_dir=self.gpg_home
        )
        self.gpg_fpr = self.gpg_store.gen_key(
            full_name='Emmy Noether',
            email='emmy.noether@uni-goettingen.de',
            passphrase=None,
            key_type='eddsa',
            subkey_type='ecdh',
            key_curve='Ed25519',
            subkey_curve='Curve25519'
        )
        # Fix GNUPG permissions
        (self.gpg_home / 'private-keys-v1.d').ensuredir()
        # 600 for files and 700 for directories
        ub.cmd('find ' + str(self.gpg_home) + r' -type f -exec chmod 600 {} \;', shell=True, verbose=self.verbose, cwd=self.gpg_home)
        ub.cmd('find ' + str(self.gpg_home) + r' -type d -exec chmod 700 {} \;', shell=True, verbose=self.verbose, cwd=self.gpg_home)

    def _setup_git(self):
        import git
        # Make a git repo and add some public content
        repo_name = 'demo-repo'
        self.repo_dpath = (self.dpath / repo_name).ensuredir()
        # self.repo_dpath.delete().ensuredir()
        self.repo_dpath.ensuredir()

        for content in self.repo_dpath.iterdir():
            content.delete()

        self.git = git.Git(self.repo_dpath)
        self.git.init()
        readme_fpath = (self.repo_dpath / 'README.md')
        readme_fpath.write_text('content')
        self.git.add(readme_fpath)

        # Create safe directory that we will encrypt
        gitattr_fpath = self.repo_dpath / '.gitattributes'
        gitattr_fpath.write_text(ub.codeblock(
            '''
            safe/* filter=crypt diff=crypt merge=crypt
            '''))
        self.git.add(gitattr_fpath)
        self.git.commit('-am Add initial contents')
        self.safe_dpath = (self.repo_dpath / 'safe').ensuredir()
        self.secret_fpath = self.safe_dpath / 'secret.txt'

    def _setup_transcrypt(self):
        self.tc = TranscryptAPI(self.repo_dpath, self.config,
                                verbose=self.verbose)
        err = self.tc.cmd(f'{self.tc.transcript_exe} -d')['err'].strip()
        if err != 'transcrypt: the current repository is not configured':
            raise AssertionError(f"Got {err}")
        self.tc.login()
        self.secret_fpath.write_text('secret content')
        self.git.add(self.secret_fpath)
        self.git.commit('-am add secret')
        self.tc.display()
        if self.gpg_home is not None:
            self.tc.env['GNUPGHOME'] = str(self.gpg_home)

    def test_round_trip(self):
        ciphertext = self.tc.show_raw(self.secret_fpath)
        plaintext = self.secret_fpath.read_text()
        assert ciphertext.startswith(SALTED)
        assert plaintext.startswith('secret content')
        assert not plaintext.startswith(SALTED)

        self.tc.logout()
        logged_out_text = self.secret_fpath.read_text()
        assert logged_out_text == ciphertext

        self.tc.login()
        logged_in_text = self.secret_fpath.read_text()

        assert logged_out_text == ciphertext
        assert logged_in_text == plaintext

    def test_export_gpg(self):
        self.tc.display()
        asc_fpath = self.tc.export_gpg(self.gpg_fpr)

        info = self.tc.cmd(f'gpg --batch --quiet --decrypt "{asc_fpath}"')
        content = info['out']

        got_config = dict([p.split('=', 1) for p in content.split('\n') if p])
        config = self.tc.config.copy()
        is_ok = got_config == config
        if not is_ok:
            if config['salt_method'] == 'configured':
                if config['config_salt'] == '':
                    config.pop('config_salt')
                    got_config.pop('config_salt')
                    is_ok = got_config == config
            else:
                config.pop('config_salt')
                got_config.pop('config_salt')
                is_ok = got_config == config

        if not is_ok:
            print(f'got_config={got_config}')
            print(f'config={config}')
            raise AssertionError

        # content = io.StringIO()
        # with open(asc_fpath, 'r') as file:
        #     ciphertext = file.read()
        # self.gpg_store.decrypt(ciphertext, content)

        assert asc_fpath.exists()
        self.tc.logout()
        self.tc.import_gpg(asc_fpath)

        plaintext = self.secret_fpath.read_text()
        assert plaintext.startswith('secret content')

    def test_rekey(self):
        # TODO
        pass


def run_tests():
    """
    CommandLine:
        xdoctest -m /home/joncrall/code/transcrypt/tests/test_transcrypt.py run_tests

    Example:
        >>> import sys, ubelt
        >>> sys.path.append(ubelt.expandpath('~/code/transcrypt/tests'))
        >>> from test_transcrypt import *  # NOQA
        >>> self = TestEnvironment()
        >>> self.setup()
        >>> self.tc._manual_hack_info()
        >>> self.test_round_trip()
        >>> self.test_export_gpg()

        self = TestEnvironment(config={'use_pbkdf2': 1})
        self.setup()
        self.test_round_trip()
        self.test_export_gpg()

        self = TestEnvironment(config={'use_pbkdf2': 1})
    """

    # Test that transcrypt works under a variety of config conditions
    basis = {
        'cipher': ['aes-256-cbc'],
        'password': ['correct horse battery staple'],
        'digest': ['md5', 'sha256'],
        'use_pbkdf2': ['0', '1'],
        'salt_method': ['password', 'configured'],
        'config_salt': ['', 'mylittlecustomsalt'],
    }

    for params in ub.named_product(basis):
        config = params.copy()
        self = TestEnvironment(config=config)
        self.setup()
        self.test_round_trip()
        self.test_export_gpg()


if __name__ == '__main__':
    """
    CommandLine:
        python ~/code/transcrypt/tests/test_transcrypt.py
    """
    run_tests()
