require "openssl"

module Bard
  class Backup
    class Encryptor
      def initialize(key)
        @encrypt_key = derive_key(key, "encryption")
        @iv_key = derive_key(key, "iv-derivation")
      end

      def encrypt(data)
        data = data.b if data.encoding != Encoding::BINARY
        iv = OpenSSL::HMAC.digest("SHA256", @iv_key, data)[0, 12]
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.encrypt
        cipher.key = @encrypt_key
        cipher.iv = iv
        ciphertext = cipher.update(data) + cipher.final
        iv + cipher.auth_tag + ciphertext
      end

      def decrypt(data)
        data = data.b if data.encoding != Encoding::BINARY
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.decrypt
        cipher.key = @encrypt_key
        cipher.iv = data[0, 12]
        cipher.auth_tag = data[12, 16]
        cipher.update(data[28..]) + cipher.final
      end

      private

      def derive_key(raw_key, info)
        OpenSSL::KDF.hkdf(raw_key, salt: "bard-backup-v1", info: info, length: 32, hash: "SHA256")
      end
    end
  end
end
