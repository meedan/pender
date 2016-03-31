<?php
namespace Meedan\Pender;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Meedan\PenderClient\PenderClient;

class MediasCommand extends Command
{
    protected function configure()
    {
        $this
            ->setName('medias')
            ->setDescription('Get info about URL')
            ->addArgument(
                'url',
                InputArgument::REQUIRED,
                'The URL you want to ask Pender about.'
            )
            ->addArgument(
                'host',
                InputArgument::REQUIRED,
                'Pender\'s location.'
            )
            ->addArgument(
                'key',
                InputArgument::REQUIRED,
                'Your Pender API key.'
            )
        ;
    }

    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $url = $input->getArgument('url');
        $host = $input->getArgument('host');
        $key = $input->getArgument('key');
        $client = new PenderClient([
          'host' => $host,
          'token_value' => $key,
        ]);
        $response = $client->get_medias($url);
        $output->writeln(print_r($response, true));
    }
}
