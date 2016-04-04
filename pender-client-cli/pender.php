#!/usr/bin/env php
<?php
// application.php

require __DIR__.'/vendor/autoload.php';

use Meedan\Pender\MediasCommand;
use Symfony\Component\Console\Application;

$application = new Application();
$application->add(new MediasCommand());
$application->run();
