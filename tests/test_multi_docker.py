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
    unshared_dpath1 = (test_dpath / 'unshared_container1').ensuredir()
    unshared_dpath2 = (test_dpath / 'unshared_container2').ensuredir()
    shared_dpath = (test_dpath / 'shared').ensuredir()

    transcrypt_repo

    from oci_container import OCIContainer
    from shlex import split as shsplit

    container1 = OCIContainer(
        image='ubuntu:20.04',
        volumes=[
            (transcrypt_repo, '/transcrypt'),
            (unshared_dpath1, '/unshared'),
            (shared_dpath, '/shared'),
        ])

    container2 = OCIContainer(
        image='ubuntu:22.04',
        volumes=[
            (transcrypt_repo, '/transcrypt'),
            (unshared_dpath2, '/unshared'),
            (shared_dpath, '/shared'),
        ])

    container1.start()
    container2.start()
    try:

        container1.call(['/bin/ls'], cwd='/unshared')
        container2.call(['/bin/ls'], cwd='/unshared')
        container1.call(['/bin/ls'], cwd='/shared')
        container2.call(['/bin/ls'], cwd='/shared')

        def setup_container(container):
            container.call(shsplit('apt-get update -y'))
            container.call(shsplit('apt-get install git bsdmainutils xxd -y'))

            container.call(shsplit(f'git config --global user.email "{container.name}@test.com"'))
            container.call(shsplit(f'git config --global user.name "{container.name}"'))
            container.call(shsplit('git config --global init.defaultBranch "main"'))

            container.call(shsplit('ls /transcrypt'))
            container.call(shsplit('mkdir -p /repos'))
            container.call(shsplit('git clone /transcrypt/.git'), cwd='/repos')
            container.call(shsplit('chmod +x /repos/transcrypt/transcrypt'), cwd='/repos')
            container.call(shsplit('ls -al /repos/transcrypt'), cwd='/repos')
            container.call(shsplit('ln -s /repos/transcrypt/transcrypt /usr/local/bin/transcrypt'), cwd='/repos')
            container.call(shsplit('transcrypt --version'), cwd='/repos/transcrypt/example')

            container.call(shsplit('git status'), cwd='/repos/transcrypt')
            container.call(shsplit('git pull'), cwd='/repos/transcrypt')
            container.call(shsplit('bash end_to_end_example.sh'), cwd='/repos/transcrypt/example')

            container.call(shsplit('ls -al /root/tmp/transcrypt-demo/demo-repo-tc-end-to-end'))
            container.call(shsplit('git clone /root/tmp/transcrypt-demo/demo-repo-tc-end-to-end/.git'), cwd='/unshared')

        # Ensure both containers have prereqs and run the end-to-end example on
        # them to initialize a simple repo.

        # container = container1
        setup_container(container1)
        setup_container(container2)

        # Setup one encrypted repo that the containers will both communicate with
        container1.call(shsplit('git clone /root/tmp/transcrypt-demo/demo-repo-tc-end-to-end/.git /shared/encrypted'), cwd='/shared')
        container1.call(shsplit('git clone /shared/encrypted/.git /shared/decrypted1'), cwd='/shared')
        container2.call(shsplit('git clone /shared/encrypted/.git /shared/decrypted2'), cwd='/shared')

        # Decrypt in each one respectively
        container1.call(shsplit("transcrypt -c aes-256-cbc -p 'correct horse battery staple' -md MD5 --kdf=pbkdf2 -y"), cwd='/shared/decrypted1')
        # Strange. This seems to modify .transcrypt/config for some reason, and
        # I don't know why or at least it says it does? It doesn't have a diff,
        # but it is modified in the git status, but it's not even an encrypted
        # file marked by gitattributes.
        container1.call(shsplit("transcrypt -d"), cwd='/shared/decrypted1')
        container1.call(shsplit("git status"), cwd='/shared/decrypted1')
        container1.call(shsplit("git diff"), cwd='/shared/decrypted1')

        container2.call(shsplit("transcrypt -F -f -y"), cwd='/shared/decrypted2')
        container2.call(shsplit("transcrypt -c aes-256-cbc -p 'correct horse battery staple' -md MD5 --kdf=pbkdf2 -y -bs 87c9f716d79a6a96bf84a5475b77c998"), cwd='/shared/decrypted2')
        container2.call(shsplit("transcrypt -d"), cwd='/shared/decrypted2')
        container2.call(shsplit("git status"), cwd='/shared/decrypted2')
        container2.call(shsplit("git diff"), cwd='/shared/decrypted2')
        container2.call(shsplit("cat safe/secret_file"), cwd='/shared/decrypted2')

        # container1.call(shsplit("cat safe/secret_file"), cwd='/shared/decrypted1')

    finally:
        container1.stop()
        container2.stop()
