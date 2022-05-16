package conversion

import (
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/btcsuite/btcd/btcec"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/peer"
	tcrypto "github.com/tendermint/tendermint/crypto"
	"github.com/tendermint/tendermint/crypto/secp256k1"
)

// GetPeerIDFromPubKey get the peer.ID from bech32 format node pub key
func GetPeerIDFromPubKey(pubkey string) (peer.ID, error) {
	pk, err := sdk.GetPubKeyFromBech32(sdk.Bech32PubKeyTypeAccPub, pubkey)
	if err != nil {
		return "", fmt.Errorf("fail to parse account pub key(%s): %w", pubkey, err)
	}
	secpPubKey := pk.(secp256k1.PubKeySecp256k1)
	ppk, err := crypto.UnmarshalSecp256k1PublicKey(secpPubKey[:])
	if err != nil {
		return "", fmt.Errorf("fail to convert pubkey to the crypto pubkey used in libp2p: %w", err)
	}
	return peer.IDFromPublicKey(ppk)
}

// GetPeerIDsFromPubKeys convert a list of node pub key to their peer.ID
func GetPeerIDsFromPubKeys(pubkeys []string) ([]string, error) {
	var peerIDs []string
	for _, item := range pubkeys {
		peerID, err := GetPeerIDFromPubKey(item)
		if err != nil {
			return nil, err
		}
		peerIDs = append(peerIDs, peerID.String())
	}
	return peerIDs, nil
}

// GetPeerIDs return a slice of peer id
func GetPeerIDs(pubkeys []string) ([]peer.ID, error) {
	var peerIDs []peer.ID
	for _, item := range pubkeys {
		pID, err := GetPeerIDFromPubKey(item)
		if err != nil {
			return nil, fmt.Errorf("fail to get peer id from pubkey(%s):%w", item, err)
		}
		peerIDs = append(peerIDs, pID)
	}
	return peerIDs, nil
}

// GetPubKeysFromPeerIDs given a list of peer ids, and get a list og pub keys.
func GetPubKeysFromPeerIDs(peers []string) ([]string, error) {
	var result []string
	for _, item := range peers {
		pKey, err := GetPubKeyFromPeerID(item)
		if err != nil {
			return nil, fmt.Errorf("fail to get pubkey from peerID: %w", err)
		}
		result = append(result, pKey)
	}
	return result, nil
}

// GetPubKeyFromPeerID extract the pub key from PeerID
func GetPubKeyFromPeerID(pID string) (string, error) {
	peerID, err := peer.Decode(pID)
	if err != nil {
		return "", fmt.Errorf("fail to decode peer id: %w", err)
	}
	pk, err := peerID.ExtractPublicKey()
	if err != nil {
		return "", fmt.Errorf("fail to extract pub key from peer id: %w", err)
	}
	rawBytes, err := pk.Raw()
	if err != nil {
		return "", fmt.Errorf("faail to get pub key raw bytes: %w", err)
	}
	var pubkey secp256k1.PubKeySecp256k1
	copy(pubkey[:], rawBytes)
	return sdk.Bech32ifyPubKey(sdk.Bech32PubKeyTypeAccPub, pubkey)
}

func GetPriKey(priKeyString string) (tcrypto.PrivKey, error) {
	priHexBytes, err := base64.StdEncoding.DecodeString(priKeyString)
	if err != nil {
		return nil, fmt.Errorf("fail to decode private key: %w", err)
	}
	rawBytes, err := hex.DecodeString(string(priHexBytes))
	if err != nil {
		return nil, fmt.Errorf("fail to hex decode private key: %w", err)
	}
	var keyBytesArray [32]byte
	copy(keyBytesArray[:], rawBytes[:32])
	priKey := secp256k1.PrivKeySecp256k1(keyBytesArray)
	return priKey, nil
}

func GetPriKeyRawBytes(priKey tcrypto.PrivKey) ([]byte, error) {
	var keyBytesArray [32]byte
	pk, ok := priKey.(secp256k1.PrivKeySecp256k1)
	if !ok {
		return nil, errors.New("private key is not secp256p1.PrivKeySecp256k1")
	}
	copy(keyBytesArray[:], pk[:])
	return keyBytesArray[:], nil
}

func CheckKeyOnCurve(pk string) (bool, error) {
	pubKey, err := sdk.GetPubKeyFromBech32(sdk.Bech32PubKeyTypeAccPub, pk)
	if err != nil {
		return false, fmt.Errorf("fail to parse pub key(%s): %w", pk, err)
	}
	rawPk := pubKey.(secp256k1.PubKeySecp256k1)
	bPk, err := btcec.ParsePubKey(rawPk[:], btcec.S256())
	if err != nil {
		return false, err
	}
	return isOnCurve(bPk.X, bPk.Y), nil
}
