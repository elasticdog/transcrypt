def main():
    """
    We are going to setup two docker images, execute transcrypt in each, and
    then make sure working on multiple machines with different openssl verions
    is handled gracefully
    """
    import ubelt as ub
    import os
    import sys
    # Hard coded
    transcrypt_repo = ub.Path('$HOME/code/transcrypt').expand()
    # Hack sys.path
    sys.path.append(os.fspath(transcrypt_repo / 'tests'))

    test_dpath = ub.Path.appdir('transcrypt/tests/')
    dpath1 = (test_dpath / 'container1').ensuredir()
    dpath2 = (test_dpath / 'container2').ensuredir()

    transcrypt_repo

    from oci_container import OCIContainer
    from shlex import split as shsplit

    container1 = OCIContainer(
        image='ubuntu:20.04',
        volumes=[
            (transcrypt_repo, '/transcrypt'),
            (dpath1, '/custom'),
        ])

    container2 = OCIContainer(
        image='ubuntu:22.04',
        volumes=[
            (transcrypt_repo, '/transcrypt'),
            (dpath2, '/custom'),
        ])

    container1.start()
    container2.start()

    container1.call(['/bin/ls'], cwd='/custom')
    container2.call(['/bin/ls'], cwd='/custom')

    def setup_container(container):
        container.call(shsplit('apt-get update -y'))
        container.call(shsplit('apt-get install git -y'))
        container.call(shsplit('git clone /transcrypt/.git'), cwd='/custom')
        container.call(shsplit(f'git config --global user.email "{container.name}@test.com"'))
        container.call(shsplit(f'git config --global user.name "{container.name}"'))
        container.call(shsplit('git config --global init.defaultBranch "main"'))

        container.call(shsplit('chmod +x /custom/transcrypt/transcrypt'), cwd='/custom')
        container.call(shsplit('ls -al /custom/transcrypt'), cwd='/custom')
        container.call(shsplit('ln -s /custom/transcrypt/transcrypt /usr/local/bin/transcrypt'), cwd='/custom')
        container.call(shsplit('transcrypt --version'), cwd='/custom/transcrypt/example')

        container.call(shsplit('git status'), cwd='/custom/transcrypt')
        container.call(shsplit('git pull'), cwd='/custom/transcrypt')
        container.call(shsplit('bash end_to_end_example.sh'), cwd='/custom/transcrypt/example')

    setup_container(container1)
    setup_container(container2)

    container1.call(shsplit('git clone /transcrypt/.git'), cwd='/custom')
    container2.call(shsplit('git clone /transcrypt/.git'), cwd='/custom')
