# blackbox_password_manager

A new unique open source password manager for iOS and Android written in Flutter.

Note: icons provided by icons8.com 

## About Blackbox Password Manager 

Blackbox Password Manager uses the standard AES encryption algorithm in CTR mode to encrypt your passwords, 
keys, notes, and other data.  We take privacy and security seriously and always enhance 
our protocols to match the evolving threat landscape in the cyber security world.  After the issues 
we observed with password managers like LastPass, we decided to take an extra step and encrypt as 
much metadata as relevantly possible to ensure the security of your information.  Metadata is just as
important to protect, as this leads to other possible avenues of attack outside of the actual 
password manager application (ie. targeted phishing campaigns).

## Key Derivation and Encryption Protocol:

Blackbox Password Manager uses PBKDF2 for key derivation that combines 
your master password with a 32 byte salt with 300,000 rounds 
to produce a 64 byte key.  This derived key gets split into two 32 byte keys,
one for encryption (derived key encryption key, dKEK) and one for authentication 
(derived key authentication key, dKAK).

A root master key (Kroot, 32 bytes) is then generated which gets expanded into its own 64 byte 
derived key and gets split into its own KEK and KAK (the master key encryption key, mKEK, and 
master key authentication key, mKAK).  The master keys are what are used to actually encrypt your data.

The derived key encryption key, dKEK encrypts the master root key Kroot.  We utilize the 
Encrypt-Then-MAC implementation whenever we encrypt data.  This means we encrypt data with the KEK,
and then HMAC (ie. keyed mac) the encrypted data with the KAK in a way that provides a true tamper proof seal.

AES-CTR(data, KEK, IV) = Edata

HMAC(SHA256(IV || Edata), KAK) = MAC 

save: IV + MAC + Edata

The IV, known as the initialization vector or nonce, is a very important parameter especially when 
using the CTR mode of operation.  We use random nonces every time we encrypt to remove the possibility
of re-using nonces.  Re-use of a nonce can break the security of the individually encrypted data, and 
possibly other pieces of encrypted data depending on the implementation.

In light of the problem of nonce reuse, we secure the encrypted data in different layers to safe guard
against the possibility of this vulnerability. It is very rare that we would re-use a nonce, but it is 
possible.  Each piece of encrypted data is saved with the above format (IV + MAC + Edata).  
This data then gets saved in the Keychain (which is itself also encrypted depending on the platform).

When a backup gets created, we take all the individually encrypted data items and create a single
JSON list object.  We then encrypt the JSON blob itself with the same protocol.  By doing this, if a nonce
does happen to get re-used within the individual items, no one can determine this because we add an 
additional encryption layer over all these items.

## Recovery Mode

Your master password is the only thing that protects you from unauthorized access to your vault.  
However, we also believe that recovery is a very important property for key management in general.
We implemented an optional recovery mode within the password manager
(Under Settings>Advanced Settings>Recovery Mode).  We use Curve25519 to enable you to share a
recovery key with other people that use Blackbox Password Manager.  

For example, Alice and Bob are friends and both have Blackbox Password Manager.  
They both can exchange their identity public keys that create a shared secret key.  
This shared secret key then can be used to separately encrypt their respective master root keys.  
If you enable a recovery key on your end, your friend has the option 
to bypass their master password by scanning the recovery key from within your vault to decrypt their vault 
(and additionally change their master password if they forget it).


## Experimental Notice

THIS APPLICATION IS FOR EXPERIMENTAL PURPOSES AT THE MOMENT.  There may be possible issues and/or bugs
within the implementation and should not be used for mission critical data unless you can verify
the application and implementation yourself.  There is also experimental code as well as unused code 
within the application that needs to be cleaned up and/or enhanced.

## Experimental Geo-Encryption

Saved Passwords and Notes are pretty straightforward.  There is a Geo-Encryption (Geo-Lock) feature 
implemented within saved passwords in which you can further secure passwords by using your current geo-location
to further encrypt the password.  This means if you enable Geo-Lock on a password, it uses your 
latitude and longitude coordinates within the nonce of the encryption protocol to lock it within a 
range of those coordinates.  You must be within a range (+/- 0.0016) of that original coordinate to 
decrypt the password item.  This is an example of an experimental feature that should be verified on your part.  It is 
important to note that geo-encryption can indeed be brute forced, but since the geo-encrypted item
is encrypted itself within the password manager it can only be brute forced if someone already has access
to the unencrypted vault itself.


## Getting Started with Flutter                                                               
                                                                                        
This project is a starting point for a Flutter application.                                   
                                                                                              
A few resources to get you started if this is your first Flutter project:                     
                                                                                              
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)           
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)                       
                                                                                              
For help getting started with Flutter development, view the                                   
[online documentation](https://docs.flutter.dev/), which offers tutorials,                    
samples, guidance on mobile development, and a full API reference.                            
                                                                                              
Setup your flutter environment by visiting flutter.dev and read through the documentation     
to get set up.                                                                                
