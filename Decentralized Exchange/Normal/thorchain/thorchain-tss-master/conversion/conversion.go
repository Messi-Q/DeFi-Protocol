package conversion

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"sort"
	"strconv"

	"github.com/binance-chain/go-sdk/common/types"
	"github.com/binance-chain/tss-lib/crypto"
	"github.com/btcsuite/btcd/btcec"
	sdk "github.com/cosmos/cosmos-sdk/types"

	btss "github.com/binance-chain/tss-lib/tss"
	crypto2 "github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/tendermint/tendermint/crypto/secp256k1"

	"gitlab.com/thorchain/tss/go-tss/messages"
)

// GetPeerIDFromSecp256PubKey convert the given pubkey into a peer.ID
func GetPeerIDFromSecp256PubKey(pk secp256k1.PubKeySecp256k1) (peer.ID, error) {
	ppk, err := crypto2.UnmarshalSecp256k1PublicKey(pk[:])
	if err != nil {
		return peer.ID(""), fmt.Errorf("fail to convert pubkey to the crypto pubkey used in libp2p: %w", err)
	}
	return peer.IDFromPublicKey(ppk)
}

func GetPeerIDFromPartyID(partyID *btss.PartyID) (peer.ID, error) {
	if partyID == nil || !partyID.ValidateBasic() {
		return "", errors.New("invalid partyID")
	}
	pkBytes := partyID.KeyInt().Bytes()
	var pk secp256k1.PubKeySecp256k1
	copy(pk[:], pkBytes)
	return GetPeerIDFromSecp256PubKey(pk)
}

func PartyIDtoPubKey(party *btss.PartyID) (string, error) {
	if party == nil || !party.ValidateBasic() {
		return "", errors.New("invalid party")
	}
	partyKeyBytes := party.GetKey()
	var pk secp256k1.PubKeySecp256k1
	copy(pk[:], partyKeyBytes)
	pubKey, err := sdk.Bech32ifyPubKey(sdk.Bech32PubKeyTypeAccPub, pk)
	if err != nil {
		return "", err
	}
	return pubKey, nil
}

func AccPubKeysFromPartyIDs(partyIDs []string, partyIDMap map[string]*btss.PartyID) ([]string, error) {
	pubKeys := make([]string, 0)
	for _, partyID := range partyIDs {
		blameParty, ok := partyIDMap[partyID]
		if !ok {
			return nil, errors.New("cannot find the blame party")
		}
		blamedPubKey, err := PartyIDtoPubKey(blameParty)
		if err != nil {
			return nil, err
		}
		pubKeys = append(pubKeys, blamedPubKey)
	}
	return pubKeys, nil
}

func SetupPartyIDMap(partiesID []*btss.PartyID) map[string]*btss.PartyID {
	partyIDMap := make(map[string]*btss.PartyID)
	for _, id := range partiesID {
		partyIDMap[id.Id] = id
	}
	return partyIDMap
}

func GetPeersID(partyIDtoP2PID map[string]peer.ID, localPeerID string) []peer.ID {
	if partyIDtoP2PID == nil {
		return nil
	}
	peerIDs := make([]peer.ID, 0, len(partyIDtoP2PID)-1)
	for _, value := range partyIDtoP2PID {
		if value.String() == localPeerID {
			continue
		}
		peerIDs = append(peerIDs, value)
	}
	return peerIDs
}

func SetupIDMaps(parties map[string]*btss.PartyID, partyIDtoP2PID map[string]peer.ID) error {
	for id, party := range parties {
		peerID, err := GetPeerIDFromPartyID(party)
		if err != nil {
			return err
		}
		partyIDtoP2PID[id] = peerID
	}
	return nil
}

func GetParties(keys []string, localPartyKey string) ([]*btss.PartyID, *btss.PartyID, error) {
	var localPartyID *btss.PartyID
	var unSortedPartiesID []*btss.PartyID
	sort.Strings(keys)
	for idx, item := range keys {
		pk, err := sdk.GetPubKeyFromBech32(sdk.Bech32PubKeyTypeAccPub, item)
		if err != nil {
			return nil, nil, fmt.Errorf("fail to get account pub key address(%s): %w", item, err)
		}
		secpPk := pk.(secp256k1.PubKeySecp256k1)
		key := new(big.Int).SetBytes(secpPk[:])
		// Set up the parameters
		// Note: The `id` and `moniker` fields are for convenience to allow you to easily track participants.
		// The `id` should be a unique string representing this party in the network and `moniker` can be anything (even left blank).
		// The `uniqueKey` is a unique identifying key for this peer (such as its p2p public key) as a big.Int.
		partyID := btss.NewPartyID(strconv.Itoa(idx), "", key)
		if item == localPartyKey {
			localPartyID = partyID
		}
		unSortedPartiesID = append(unSortedPartiesID, partyID)
	}
	if localPartyID == nil {
		return nil, nil, errors.New("local party is not in the list")
	}

	partiesID := btss.SortPartyIDs(unSortedPartiesID)
	return partiesID, localPartyID, nil
}

func GetKeyGenUicast() string {
	return messages.KEYGEN2aUnicast
}

func GetPreviousKeySignUicast(current string) string {
	switch current {
	case messages.KEYSIGN1b:
		return messages.KEYSIGN1aUnicast
	default:
		return messages.KEYSIGN2Unicast
	}
}

func isOnCurve(x, y *big.Int) bool {
	curve := btcec.S256()
	return curve.IsOnCurve(x, y)
}

func GetTssPubKey(pubKeyPoint *crypto.ECPoint) (string, types.AccAddress, error) {
	// we check whether the point is on curve according to Kudelski report
	if pubKeyPoint == nil || !isOnCurve(pubKeyPoint.X(), pubKeyPoint.Y()) {
		return "", types.AccAddress{}, errors.New("invalid points")
	}
	tssPubKey := btcec.PublicKey{
		Curve: btcec.S256(),
		X:     pubKeyPoint.X(),
		Y:     pubKeyPoint.Y(),
	}
	var pubKeyCompressed secp256k1.PubKeySecp256k1
	copy(pubKeyCompressed[:], tssPubKey.SerializeCompressed())
	pubKey, err := sdk.Bech32ifyPubKey(sdk.Bech32PubKeyTypeAccPub, pubKeyCompressed)
	addr := types.AccAddress(pubKeyCompressed.Address().Bytes())
	return pubKey, addr, err
}

func BytesToHashString(msg []byte) (string, error) {
	h := sha256.New()
	_, err := h.Write(msg)
	if err != nil {
		return "", fmt.Errorf("fail to caculate sha256 hash: %w", err)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
