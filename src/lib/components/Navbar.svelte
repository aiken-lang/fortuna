<script lang="ts">
  import { page } from '$app/stores';
  import fortunaLogo from '$lib/assets/fortunaLogo.png';
  import ConnectButton from './ConnectButton.svelte';
</script>

<nav class="px-6 py-3 pt-6 shadow border-b border-slate-700">
  <div class="flex flex-col container mx-auto md:flex-row md:items-center md:justify-between">
    <div class="flex justify-between items-center">
      <div>
        <a href="/"><img src={fortunaLogo} alt="logo" class="md:max-w-[200px] max-w-[20vh]" /></a>
      </div>
    </div>

    <div class="md:flex flex-col md:flex-row md:-mx-4 hidden items-center font-medium text-white">
      <a
        href="/hardfork"
        class="my-1 hover:text-primary hover:border-primary md:mx-4 md:my-0"
        class:border-b-2={$page.url.pathname === '/hardfork'}
        class:border-secondary={$page.url.pathname === '/hardfork'}>Hardfork</a>

      <a
        href="/mine"
        class="my-1 hover:text-primary hover:border-primary md:mx-4 md:my-0"
        class:border-b-2={$page.url.pathname === '/mine'}
        class:border-secondary={$page.url.pathname === '/mine'}>Mine</a>

      <a
        href="/explorer"
        class="my-1 hover:text-primary hover:border-primary md:mx-4 md:my-0"
        class:border-b-2={$page.url.pathname === '/explorer'}
        class:border-secondary={$page.url.pathname === '/explorer'}>Explorer</a>

      <a
        href="/community"
        class="my-1 hover:text-primary hover:border-primary md:mx-4 md:my-0"
        class:border-b-2={$page.url.pathname === '/community'}
        class:border-secondary={$page.url.pathname === '/community'}>Community</a>
    </div>

    <div class="md:flex">
      <div class="md:flex flex-col md:flex-row md:-mx-2 items-center">
        <!-- {github icon} -->
        <a href="https://github.com/aiken-lang/fortuna" target="_blank" class=" hover:text-primary"
          ><svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="0 0 24 24"
            ><path
              d="M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4.44c-.32-.07-.33-.68-.33-.89l.01-2.47c0-.84-.29-1.39-.61-1.67c2.01-.22 4.11-.97 4.11-4.44c0-.98-.35-1.79-.92-2.42c.09-.22.4-1.14-.09-2.38c0 0-.76-.23-2.48.93c-.72-.2-1.48-.3-2.25-.31c-.76.01-1.54.11-2.25.31c-1.72-1.16-2.48-.93-2.48-.93c-.49 1.24-.18 2.16-.09 2.38c-.57.63-.92 1.44-.92 2.42c0 3.47 2.1 4.22 4.1 4.47c-.26.2-.49.6-.57 1.18c-.52.23-1.82.63-2.62-.75c0 0-.48-.86-1.38-.93c0 0-.88 0-.06.55c0 0 .59.28 1 1.32c0 0 .52 1.75 3.03 1.21l.01 1.53c0 .21-.02.82-.34.89H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"
              fill="currentColor" /></svg
          ></a>
        <!-- {discord icon} -->
        <a href="https://discord.gg/Vc3x8N9nz2" target="_blank" class="mx-4"
          ><svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 256 256"
            ><g fill="none"
              ><rect width="256" height="256" fill="#5865F2" rx="60" /><g
                clip-path="url(#skillIconsDiscord0)"
                ><path
                  fill="#fff"
                  d="M197.308 64.797a164.918 164.918 0 0 0-40.709-12.627a.618.618 0 0 0-.654.31c-1.758 3.126-3.706 7.206-5.069 10.412c-15.373-2.302-30.666-2.302-45.723 0c-1.364-3.278-3.382-7.286-5.148-10.412a.643.643 0 0 0-.655-.31a164.472 164.472 0 0 0-40.709 12.627a.583.583 0 0 0-.268.23c-25.928 38.736-33.03 76.52-29.546 113.836a.685.685 0 0 0 .26.468c17.106 12.563 33.677 20.19 49.94 25.245a.648.648 0 0 0 .702-.23c3.847-5.254 7.276-10.793 10.217-16.618a.633.633 0 0 0-.347-.881c-5.44-2.064-10.619-4.579-15.601-7.436a.642.642 0 0 1-.063-1.064a86.364 86.364 0 0 0 3.098-2.428a.618.618 0 0 1 .646-.088c32.732 14.944 68.167 14.944 100.512 0a.617.617 0 0 1 .655.08a79.613 79.613 0 0 0 3.106 2.436a.642.642 0 0 1-.055 1.064a102.622 102.622 0 0 1-15.609 7.428a.638.638 0 0 0-.339.889a133.075 133.075 0 0 0 10.208 16.61a.636.636 0 0 0 .702.238c16.342-5.055 32.913-12.682 50.02-25.245a.646.646 0 0 0 .26-.46c4.17-43.141-6.985-80.616-29.571-113.836a.506.506 0 0 0-.26-.238M94.834 156.142c-9.855 0-17.975-9.047-17.975-20.158s7.963-20.158 17.975-20.158c10.09 0 18.131 9.127 17.973 20.158c0 11.111-7.962 20.158-17.973 20.158m66.456 0c-9.855 0-17.974-9.047-17.974-20.158s7.962-20.158 17.974-20.158c10.09 0 18.131 9.127 17.974 20.158c0 11.111-7.884 20.158-17.974 20.158" /></g
              ><defs
                ><clipPath id="skillIconsDiscord0"
                  ><path fill="#fff" d="M28 51h200v154.93H28z" /></clipPath
                ></defs
              ></g
            ></svg
          ></a>
      </div>
      <ConnectButton />
    </div>
  </div>
</nav>
