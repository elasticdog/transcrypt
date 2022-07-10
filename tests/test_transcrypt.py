"""
This file provides a Python wrapper around the transcrypt API for the purpose
of testing.

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
        >>> from test_transcrypt import *  # NOQA
        >>> sandbox = DemoSandbox(verbose=1, dpath='special:cache').setup()
        >>> config = {'digest': 'sha256',
        >>>           'kdf': 'pbkdf2',
        >>>           'base_salt': '665896be121e1a0a4a7b18f01780061'}
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
        >>> raw_texts = [self.show_raw(p) for p in [secret_fpath1, secret_fpath2, secret_fpath3]]
        >>> print('raw_texts = {}'.format(ub.repr2(raw_texts, nl=1)))
        >>> assert raw_texts == [
        >>>     'U2FsdGVkX18147KP5UmqOFywveuOGf4hCwrWpfJDp3Ah0HHbFPEGdJE0kM4npWzI',
        >>>     'U2FsdGVkX183LEAwwnJ0ne/OKU5VANJsOqCA92Oi9hVkKHIwZYiCgJOoedoShPj7',
        >>>     'U2FsdGVkX1/NdLm6twCdF3xYLPCfXacDNsHEeGq0UBC1fwTlJKnN2KmPysS/ylPj',
        >>> ]
    """
    default_config = {
        'cipher': 'aes-256-cbc',
        'password': None,
        'digest': 'md5',
        'kdf': 'none',
        'base_salt': 'password',
        'use_versioned_config': None,
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
        flags_and_keys = [
            ('-c', 'cipher'),
            ('-p', 'password'),
            ('-md', 'digest'),
            ('--kdf', 'kdf'),
            ('-bs', 'base_salt'),
            ('-vc', 'use_versioned_config'),
        ]
        args = []
        for flag, key in flags_and_keys:
            value = self.config.get(key, None)
            if value is not None:
                args.append(flag)
                args.append(value)
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
        self.config['base_salt'] = self._load_unversioned_config()['base_salt']

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
        self.config['base_salt'] = self._load_unversioned_config()['base_salt']

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
        info = self._cmd('git config --local transcrypt.crypt-dir', check=0,
                         verbose=0)
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

    def _load_unversioned_config(self):
        if self.verbose > 0:
            print('Loading unversioned config')
        local_config = {
            'use_versioned_config': self._cmd('git config --get --local transcrypt.use-versioned-config', verbose=0)['out'].strip(),
            'cipher': self._cmd('git config --get --local transcrypt.cipher', verbose=0)['out'].strip(),
            'digest': self._cmd('git config --get --local transcrypt.digest', verbose=0)['out'].strip(),
            'kdf': self._cmd('git config --get --local transcrypt.kdf', verbose=0)['out'].strip(),
            'base_salt': self._cmd('git config --get --local transcrypt.base-salt', verbose=0)['out'].strip(),
            'password': self._cmd('git config --get --local transcrypt.password', verbose=0)['out'].strip(),
            'openssl_path': self._cmd('git config --get --local transcrypt.openssl-path', verbose=0)['out'].strip(),
        }
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
        if self.verbose > 1:
            self._show_manual_env_setup()
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
        if self.verbose:
            pass

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

    def _show_manual_env_setup(self):
        """
        Info on how to get an env to run a failing command manually
        """
        for k, v in self.env.items():
            print(f'export {k}={v}')
        print(f'cd {self.repo_dpath}')


class TestCases:
    """
    Unit tests to be applied to different transcrypt configurations

    xdoctest -m tests/test_transcrypt.py TestCases

    Example:
        >>> from test_transcrypt import *  # NOQA
        >>> self = TestCases(verbose=2)
        >>> self.setup()
        >>> self.sandbox._show_manual_env_setup()
        >>> self.test_round_trip()
        >>> self.test_export_gpg()
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

        if 0:
            print(self.sandbox.git.status())
            self.sandbox.git.diff()

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
        # FIXME
        is_ok = got_config == config
        if not is_ok:
            is_ok = all([got_config[k] == config[k] for k in {'digest', 'password', 'cipher', 'kdf'}])

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
            'kdf': 'pbkdf2',
            'base_salt': 'random',
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
        'kdf': 'none',
        'base_salt': '',
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
        'kdf': 'pbkdf2',
        'base_salt': 'random',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    self.test_round_trip()
    self.test_export_gpg()


def test_configured_salt_changes_on_rekey():
    """
    CommandLine:
        xdoctest -m tests/test_transcrypt.py test_configured_salt_changes_on_rekey
    """
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'kdf': 'pbkdf2',
        'base_salt': 'random',
    }
    verbose = 2
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    before_config = self.tc._load_unversioned_config()
    self.tc.rekey({'password': '12345', 'base_salt': ''})
    self.sandbox.git.commit('-am commit rekey')
    after_config = self.tc._load_unversioned_config()
    assert before_config['password'] != after_config['password'], 'password should have changed!'
    assert before_config['base_salt'] != after_config['base_salt'], 'salt should have changed!'
    assert before_config['cipher'] == after_config['cipher']
    assert before_config['kdf'] == after_config['kdf']
    assert before_config['openssl_path'] == after_config['openssl_path']


def test_unspecified_salt_without_kdf():
    """
    In this case the salt should default to the password method
    """
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'kdf': '',
        'base_salt': None,
    }
    verbose = 2
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert config1['base_salt'] == 'password'


def test_unspecified_salt_with_kdf():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'kdf': 'pbkdf2',
        'base_salt': None,
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert len(config1['base_salt']) == 64


def test_legacy_settings_dont_use_the_versioned_config():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'kdf': 'none',
        'base_salt': None,
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert not (self.sandbox.dpath / '.transcrypt').exists()
    assert config1['use_versioned_config'] == '0'


def test_pbkdf_does_use_the_versioned_config():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'kdf': 'pbkdf2',
        'base_salt': None,
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert config1['use_versioned_config'] == '1'
    assert not (self.sandbox.dpath / '.transcrypt').exists()


def test_force_use_versioned_config_1():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'kdf': 'none',
        'base_salt': None,
        'use_versioned_config': '1',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert config1['use_versioned_config'] == '1'
    assert not (self.sandbox.dpath / '.transcrypt').exists()


def test_force_use_versioned_config_0():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'kdf': 'pbkdf2',
        'base_salt': None,
        'use_versioned_config': '0',
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert not (self.sandbox.dpath / '.transcrypt').exists()
    assert config1['use_versioned_config'] == '0'


def test_salt_changes_when_kdf_changes():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'kdf': '',
        'base_salt': None,
    }
    verbose = 2
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert config1['base_salt'] == 'password'
    # Test rekey, base-salt should still be password
    self.tc.rekey({'password': '12345'})
    config2 = self.tc._load_unversioned_config()
    assert config2['base_salt'] == 'password'
    self.sandbox.git.commit('-am commit rekey')

    # Test rekey with kdf=pbkdf2 base-salt should now randomize
    self.tc.rekey({'password': '12345', 'kdf': 'pbkdf2', 'base_salt': None})
    config3 = self.tc._load_unversioned_config()
    assert len(config3['base_salt']) == 64, 'should have had new random salt'
    self.sandbox.git.commit('-am commit rekey')

    # Test rekey going back to no kdf
    self.tc.rekey({'password': '12345', 'kdf': 'none', 'base_salt': None})
    config4 = self.tc._load_unversioned_config()
    assert config4['base_salt'] == 'password'


def test_unsupported_kdf():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'sha512',
        'kdf': 'MY_FAVORITE_UNSUPPORTED_KDF',
        'base_salt': None,
    }
    verbose = 2
    self = TestCases(config=config, verbose=verbose)
    import subprocess
    import pytest
    with pytest.raises(subprocess.CalledProcessError):
        self.setup()


def test_kdf_setting_preserved_on_rekey():
    config = {
        'cipher': 'aes-256-cbc',
        'password': 'correct horse battery staple',
        'digest': 'md5',
        'kdf': 'pbkdf2',
        'base_salt': None,
    }
    verbose = 1
    self = TestCases(config=config, verbose=verbose)
    self.setup()
    config1 = self.tc._load_unversioned_config()
    assert len(config1['base_salt']) == 64

    # Explicitly don't pass kdf or base salt.
    # Transcrypt should reuse the existing kdf setting (but the salt should
    # change)
    self.tc.rekey({'kdf': None, 'base_salt': None, 'digest': 'SHA512'})
    config2 = self.tc._load_unversioned_config()
    assert config2['kdf'] == 'pbkdf2'
    assert config1['base_salt'] != config2['base_salt']
    assert len(config1['base_salt']) == 64
    assert len(config2['base_salt']) == 64


def test_configuration_grid():
    """
    CommandLine:
        xdoctest -m tests/test_transcrypt.py test_configuration_grid
    """
    # Test that transcrypt works under a variety of config conditions
    basis = {
        'cipher': ['aes-256-cbc', 'aes-128-ecb'],
        'password': ['correct horse battery staple'],
        'digest': ['md5', 'sha256'],
        'kdf': ['none', 'pbkdf2', 'scrypt'],
        'base_salt': ['password', 'random', 'mylittlecustomsalt', None],
        'use_versioned_config': ['0', '1', None],
    }

    test_grid = list(ub.named_product(basis))

    def validate_test_grid(params):
        if params['kdf'] == 'none' and params['base_salt'] != 'password':
            return False
        if params['kdf'] != 'none' and params['base_salt'] == 'password':
            return False
        return True

    # Remove invalid configs
    valid_test_grid = list(filter(validate_test_grid, test_grid))
    print('valid_test_grid = {}'.format(ub.repr2(valid_test_grid, sort=0, nl=1)))

    verbose = 2
    dpath = 'special:temp'
    dpath = 'special:cache'
    for params in ub.ProgIter(valid_test_grid, desc='test configs', freq=1,
                              verbose=verbose + 1):
        if verbose:
            print('\n\n')
            print('=================')
            print('params = {}'.format(ub.repr2(params, nl=1)))
            print('=================')

        config = params.copy()
        self = TestCases(config=config, dpath=dpath, verbose=verbose)
        self.setup()
        self.test_round_trip()
        self.test_export_gpg()
        self.test_rekey()
        if verbose:
            print('=================')

if __name__ == '__main__':
    """
    CommandLine:
        python tests/test_transcrypt.py

        # Runs everything
        pytest tests/test_transcrypt.py -v -s
    """
    test_configuration_grid()
