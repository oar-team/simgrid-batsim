/* Copyright (c) 2007, 2009-2015. The SimGrid Team.
 * All rights reserved.                                                     */

/* This program is free software; you can redistribute it and/or modify it
 * under the terms of the license (GNU LGPL) which comes with this package. */

#include "simgrid/msg.h"

XBT_LOG_NEW_DEFAULT_CATEGORY(msg_process_suspend, "Messages specific for this msg example");

/* The Lazy guy only wants to sleep, but can be awaken by the dream_master process. */
static int lazy_guy(int argc, char *argv[])
{
  XBT_INFO("Nobody's watching me ? Let's go to sleep.");
  MSG_process_suspend(MSG_process_self());       /* - Start by suspending itself */
  XBT_INFO("Uuuh ? Did somebody call me ?");

  XBT_INFO("Going to sleep...");                 /* - Then repetitively go to sleep, but got awaken */
  MSG_process_sleep(10.0);
  XBT_INFO("Mmm... waking up.");

  XBT_INFO("Going to sleep one more time...");
  MSG_process_sleep(10.0);
  XBT_INFO("Waking up once for all!");

  XBT_INFO("Mmmh, goodbye now.");
  return 0;
}

/* The Dream master: */
static int dream_master(int argc, char *argv[])
{
  msg_process_t lazy = NULL;

  XBT_INFO("Let's create a lazy guy."); /* - Create a lazy_guy process */
  lazy = MSG_process_create("Lazy", lazy_guy, NULL, MSG_host_self());
  XBT_INFO("Let's wait a little bit...");
  MSG_process_sleep(10.0);              /* - Wait for 10 seconds */
  XBT_INFO("Let's wake the lazy guy up! >:) BOOOOOUUUHHH!!!!");
  MSG_process_resume(lazy);             /* - Then wake up the lazy_guy */

  MSG_process_sleep(5.0);               /* Repeat two times: */
  XBT_INFO("Suspend the lazy guy while he's sleeping...");
  MSG_process_suspend(lazy);            /* - Suspend the lazy_guy while he's asleep */
  XBT_INFO("Let him finish his siesta.");
  MSG_process_sleep(10.0);              /* - Wait for 10 seconds */
  XBT_INFO("Wake up, lazy guy!");
  MSG_process_resume(lazy);             /* - Then wake up the lazy_guy again */

  MSG_process_sleep(5.0);
  XBT_INFO("Suspend again the lazy guy while he's sleeping...");
  MSG_process_suspend(lazy);
  XBT_INFO("This time, don't let him finish his siesta.");
  MSG_process_sleep(2.0);
  XBT_INFO("Wake up, lazy guy!");
  MSG_process_resume(lazy);

  XBT_INFO("OK, goodbye now.");
  return 0;
}

int main(int argc, char *argv[])
{
  msg_error_t res = MSG_OK;

  MSG_init(&argc, argv);
  xbt_assert(argc > 1, "Usage: %s platform_file\n\tExample: %s msg_platform.xml\n", argv[0], argv[0]);

  MSG_create_environment(argv[1]);  /* - Load the platform description */
  MSG_function_register("dream_master", dream_master); /* - Create and deploy the dream_master */
  xbt_dynar_t hosts = MSG_hosts_as_dynar();
  MSG_process_create("dream_master", dream_master, NULL, xbt_dynar_getfirst_as(hosts, msg_host_t));
  xbt_dynar_free(&hosts);
  res = MSG_main();                 /* - Run the simulation */

  XBT_INFO("Simulation time %g", MSG_get_clock());
  return res != MSG_OK;
}
