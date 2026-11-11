# Steam library transport reference

> Fork reference reconstructed from the public v0.1.653 code and notices.
> The upstream public Git tree and source archive omit this document.
> This is not recovered upstream prose or device-test evidence.

The native SwiftSteam connection, transport errors and CM-server handling include work adapted from kuscholar/iDeck. The individual Swift source headers preserve the authorship and licence notices.

Steam CM retries use classified transport failures and sanitized log domains/codes. A build-time check is tests/host/check-steam-cm-transport.py. Library, manifests, downloads, DLC, cloud and Workshop have separate checks under tests/host/check-steam-*.py. These source and fixture checks are not evidence that account sign-in, network fallback or an installed game succeeded on a phone.
