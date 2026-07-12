;; Conservative Guix channel setup.
;;
;; Keep the official Guix channel only by default.  Add nonfree or third-party
;; channels explicitly on the target machine if CUDA, proprietary fonts or
;; nonfree language runtimes become necessary.

(list
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  (branch "master")
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
     "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA")))))
