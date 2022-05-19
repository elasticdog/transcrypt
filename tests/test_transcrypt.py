"""
Requirements:
    pip install ubelt
    pip install gpg_lite
    pip install GitPython
"""
import ubelt as ub

__salt_notes__ = '''
    import base64
    salted_bytes = b'Salted'
    base64.b64encode(salted_bytes)
'''
SALTED_B64 = 'U2FsdGVk'


class Transcrypt(ub.NiceRepr):
    """
    A Python wrapper around the Transcrypt API

    Example:
        >>> import sys, ubelt
        >>> sys.path.append(ubelt.expandpath('~/code/transcrypt/tests'))
        >>> from test_transcrypt import *  # NOQA
        >>> sandbox = DemoSandbox(verbose=1, dpath='special:cache').setup()
        >>> config = {'digest': 'sha256',
        >>>           'use_pbkdf2': '1',
        >>>           'config_salt': '665896be121e1a0a4a7b18f01780061',
        >>>           'salt_method': 'configured'}
        >>> self = Transcrypt(sandbox.repo_dpath,
        >>>                   config=config, env=sandbox.env, verbose=1)
        >>> print(self.version())
        >>> self.config['password'] = 'chbs'
        >>> self.login()
        >>> sandbox.git.commit('-am', 'new salt config')
        >>> print(self.display())
        >>> secret_fpath1 = self.dpath / 'safe/secret1.txt'
        >>> secret_fpath2 = self.dpath / 'safe/secret2.txt'
        >>> secret_fpath3 = self.dpath / 'safe/secret3.txt'
        >>> secret_fpath1.write_text('secret message 1')
        >>> secret_fpath2.write_text('secret message 2')
        >>> secret_fpath3.write_text('secret message 3')
        >>> sandbox.git.add(secret_fpath1, secret_fpath2, secret_fpath3)
        >>> sandbox.git.commit('-am', 'add secret messages')
        >>> encrypted_paths = self.list()
        >>> assert len(encrypted_paths) == 3
        >>> assert self.show_raw(secret_fpath1) == 'U2FsdGVkX18147KP5UmqOFywveuOGf4hCwrWpfJDp3Ah0HHbFPEGdJE0kM4npWzI'
        >>> assert self.show_raw(secret_fpath2) == 'U2FsdGVkX183LEAwwnJ0ne/OKU5VANJsOqCA92Oi9hVkKHIwZYiCgJOoedoShPj7'
        >>> assert self.show_raw(secret_fpath3) == 'U2FsdGVkX1/NdLm6twCdF3xYLPCfXacDNsHEeGq0UBC1fwTlJKnN2KmPysS/ylPj'
    """
    default_config = {
        'cipher': 'aes-256-cbc',
        'password': None,
        'digest': 'md5',
        'use_pbkdf2': '0',
        'salt_method': 'password',
        'config_salt': '',
    }

    def __init__(self, dpath, config=None, env=None, transcript_exe=None, verbose=0):
        self.dpath = dpath
        self.verbose = verbose
        self.transcript_exe = ub.Path(ub.find_exe('transcrypt'))
        self.env = {}
        self.config = self.default_config.copy()
        if env is not None:
            self.env.update(env)
        if config:
            self.config.update(config)

    def __nice__(self):
        return '{}, {}'.format(self.dpath, ub.repr2(self.config))

    def _cmd(self, command, shell=False, check=True, verbose=None):
        """
        Helper to execute underlying transcrypt commands
        """
        if verbose is None:
            verbose = self.verbose
        return ub.cmd(command, cwd=self.dpath, verbose=verbose, env=self.env,
                      shell=shell, check=check)

    def _config_args(self):
        arg_templates = [
            "-c", self.config['cipher'],
            "-p", self.config['password'],
            "-md", self.config['digest'],
            "--use-pbkdf2", self.config['use_pbkdf2'],
            "-sm", self.config['salt_method'],
            "-cs", self.config['config_salt'],
        ]
        args = [template.format(**self.config) for template in arg_templates]
        return args

    def is_configured(self):
        """
        Determine if the transcrypt credentials are populated in the repo

        Returns:
            bool : True if the repo is configured with credentials
        """
        info = self._cmd(f'{self.transcript_exe} -d', check=0, verbose=0)
        return info['ret'] == 0

    def login(self):
        """
        Configure credentials
        """
        args = self._config_args()
        command = [str(self.transcript_exe), *args, '-y']
        self._cmd(command)

    def logout(self):
        """
        Flush credentials
        """
        self._cmd(f'{self.transcript_exe} -f -y')

    def rekey(self, new_config):
        """
        Re-encrypt all encrypted files using new credentials
        """
        self.config.update(new_config)
        args = self._config_args()
        command = [str(self.transcript_exe), '--rekey', *args, '-y']
        self._cmd(command)

    def display(self):
        """
        Returns:
            str: the configuration details of the repo
        """
        return self._cmd(f'{self.transcript_exe} -d')['out'].rstrip()

    def version(self):
        """
        Returns:
            str: the version
        """
        return self._cmd(f'{self.transcript_exe} --version')['out'].rstrip()

    def _crypt_dir(self):
        info = self._cmd('git config --local transcrypt.crypt-dir', check=0)
        if info['err'] == 0:
            crypt_dpath = ub.Path(info['out'].strip())
        else:
            crypt_dpath = self.dpath / '.git/crypt'
        return crypt_dpath

    def export_gpg(self, recipient):
        """
        Encode the transcrypt credentials securely in an encrypted gpg message

        Returns:
            Path: path to the gpg encrypted file containing the repo config
        """
        self._cmd(f'{self.transcript_exe} --export-gpg "{recipient}"')
        crypt_dpath = self._crypt_dir()
        asc_fpath = (crypt_dpath / (recipient + '.asc'))
        return asc_fpath

    def import_gpg(self, asc_fpath):
        """
        Configure the repo using a given gpg encrypted file
        """
        command = f"{self.transcript_exe} --import-gpg '{asc_fpath}' -y"
        self._cmd(command)

    def show_raw(self, fpath):
        """
        Show the encrypted contents of a file that will be publicly viewable
        """
        return self._cmd(f'{self.transcript_exe} -s {fpath}')['out'].rstrip()

    def list(self):
        """
        Returns:
            List[str]: relative paths of all files managed by transcrypt
        """
        result = self._cmd(f'{self.transcript_exe} --list')['out'].rstrip()
        paths = result.split('\n')
        return paths

    def uninstall(self):
        """
        Flushes credentials and removes transcrypt files
        """
        return self._cmd(f'{self.transcript_exe} --uninstall -y')

    def upgrade(self):
        """
        Upgrades a configured repo to "this" version of transcrypt
        """
        return self._cmd(f'{self.transcript_exe} --upgrade -y')

    def _load_local_config(self):
        local_config = {
            'cipher': self._cmd('git config --get --local transcrypt.cipher')['out'].strip(),
            'digest': self._cmd('git config --get --local transcrypt.digest')['out'].strip(),
            'use_pbkdf2': self._cmd('git config --get --local transcrypt.use-pbkdf2')['out'].strip(),
            'salt_method': self._cmd('git config --get --local transcrypt.salt-method')['out'].strip(),
            'password': self._cmd('git config --get --local transcrypt.password')['out'].strip(),
            'openssl_path': self._cmd('git config --get --local transcrypt.openssl-path')['out'].strip(),
        }
        if local_config['salt_method'] == 'configured':
            tc_config_path = self.dpath / '.transcrypt/config'
            local_config['config_salt'] = self._cmd(f'git config --get --file {tc_config_path} transcrypt.config-salt')['out'].strip()
        return local_config


class DemoSandbox(ub.NiceRepr):
    """
    A environment for demo / testing of the transcrypt API
    """
    def __init__(self, dpath=None, verbose=0):
        if dpath is None:
            dpath = 'special:temp'

        if dpath == 'special:temp':
            import tempfile
            self._tmpdir = tempfile.TemporaryDirectory()
            dpath = self._tmpdir.name
        elif dpath == 'special:cache':
            dpath = ub.Path.appdir('transcrypt/tests/test_env')
        self.env = {}
        self.dpath = ub.Path(dpath)
        self.gpg_store = None
        self.repo_dpath = None
        self.git = None
        self.verbose = verbose

    def __nice__(self):
        return str(self.dpath)

    def setup(self):
        self._setup_gpghome()
        self._setup_gitrepo()
        self._setup_contents()
        return self

    def _setup_gpghome(self):
        if self.verbose:
            print('setup sandbox gpghome')
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
        ub.cmd('find ' + str(self.gpg_home) + r' -type f -exec chmod 600 {} \;', shell=True, cwd=self.gpg_home)
        ub.cmd('find ' + str(self.gpg_home) + r' -type d -exec chmod 700 {} \;', shell=True, cwd=self.gpg_home)
        self.env['GNUPGHOME'] = str(self.gpg_home)

    def _setup_gitrepo(self):
        if self.verbose:
            print('setup sandbox gitrepo')
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

    def _setup_contents(self):
        if self.verbose:
            print('setup sandbox git contents')
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
        self.secret_fpath.write_text('secret content')

    def _manual_hack_info(self):
        """
        Info on how to get an env to run a failing command manually
        """
        for k, v in self.env.items():
            print(f'export {k}={v}')
        print(f'cd {self.repo_dpath}')


class TestCases:
    """
    Unit tests to be applied to different transcrypt configurations
    """

    def __init__(self, config=None, dpath=None, verbose=0):
        if config is None:
            config = Transcrypt.default_config
            config['password'] = '12345'
        self.config = config
        self.verbose = verbose
        self.sandbox = None
        self.tc = None
        self.dpath = dpath

    def setup(self):
        self.sandbox = DemoSandbox(dpath=self.dpath, verbose=self.verbose)
        self.sandbox.setup()
        self.tc = Transcrypt(
            dpath=self.sandbox.repo_dpath,
            config=self.config,
            env=self.sandbox.env,
            verbose=self.verbose,
        )
        assert not self.tc.is_configured()
        self.tc.login()
        secret_fpath = self.sandbox.secret_fpath
        self.sandbox.git.add(secret_fpath)
        self.sandbox.git.commit('-am add secret')
        self.tc.display()

    def test_round_trip(self):
        secret_fpath = self.sandbox.secret_fpath
        ciphertext = self.tc.show_raw(secret_fpath)
        plaintext = secret_fpath.read_text()
        assert ciphertext.startswith(SALTED_B64)
        assert plaintext.startswith('secret content')
        assert not plaintext.startswith(SALTED_B64)

        self.tc.logout()
        logged_out_text = secret_fpath.read_text().rstrip()
        assert logged_out_text == ciphertext

        self.tc.login()
        logged_in_text = secret_fpath.read_text().rstrip()

        assert logged_out_text == ciphertext
        assert logged_in_text == plaintext

    def test_export_gpg(self):
        self.tc.display()
        recipient = self.sandbox.gpg_fpr
        asc_fpath = self.tc.export_gpg(recipient)

        info = self.tc._cmd(f'gpg --batch --quiet --decrypt "{asc_fpath}"')
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

        assert asc_fpath.exists()
        self.tc.logout()
        self.tc.import_gpg(asc_fpath)

        secret_fpath = self.sandbox.secret_fpath
        plaintext = secret_fpath.read_text()
        assert plaintext.startswith('secret content')

    def test_rekey(self):
        new_config = {
            'cipher': 'aes-256-cbc',
            'password': '12345',
            'digest': 'sha256',
            'use_pbkdf2': '1',
            'salt_method': 'configured',
        }
        raw_before = self.tc.show_raw(self.sandbox.secret_fpath)
        self.tc.rekey(new_config)
        self.sandbox.git.commit('-am commit rekey')
        raw_after = self.tc.show_raw(self.sandbox.secret_fpath)
        assert raw_before != raw_after


def test_legacy_defaults():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'use_pbkdf2': '0',
        'salt_method': 'password',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    self.test_round_trip()
    self.test_export_gpg()


def test_secure_defaults():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'use_pbkdf2': '1',
        'salt_method': 'configured',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    self.test_round_trip()
    self.test_export_gpg()


def test_configured_salt_changes_on_rekey():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'use_pbkdf2': '1',
        'salt_method': 'configured',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    before_config = self.tc._load_local_config()
    self.tc.rekey({'password': '12345', 'config_salt': ''})
    self.sandbox.git.commit('-am commit rekey')
    after_config = self.tc._load_local_config()
    assert before_config['config_salt'] != after_config['config_salt']
    assert before_config['password'] != after_config['password']
    assert before_config['cipher'] == after_config['cipher']
    assert before_config['use_pbkdf2'] == after_config['use_pbkdf2']
    assert before_config['salt_method'] == after_config['salt_method']
    assert before_config['openssl_path'] == after_config['openssl_path']


def test_configuration_grid():
    """
    CommandLine:
        xdoctest -m tests/test_transcrypt.py test_configuration_grid

    Example:
        >>> import sys, ubelt
        >>> sys.path.append(ubelt.expandpath('~/code/transcrypt/tests'))
        >>> from test_transcrypt import *  # NOQA
        >>> self = TestCases()
        >>> self.setup()
        >>> self.sandbox._manual_hack_info()
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
        'cipher': ['aes-256-cbc', 'aes-128-ecb'],
        'password': ['correct horse battery staple'],
        'digest': ['md5', 'sha256'],
        'use_pbkdf2': ['0', '1'],
        'salt_method': ['password', 'configured'],
        'config_salt': ['', 'mylittlecustomsalt'],
    }
    test_grid = list(ub.named_product(basis))
    dpath = 'special:temp'
    dpath = 'special:cache'
    for params in ub.ProgIter(test_grid, desc='test configs', freq=1):
        config = params.copy()
        self = TestCases(config=config, dpath=dpath)
        self.setup()
        if 0:
            # Manual debug
            self.sandbox._manual_hack_info()

        self.test_round_trip()
        self.test_export_gpg()
        self.test_rekey()


if __name__ == '__main__':
    """
    CommandLine:
        python ~/code/transcrypt/tests/test_transcrypt.py
    """
    test_configuration_grid()
