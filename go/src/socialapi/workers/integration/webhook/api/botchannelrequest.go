package api

import (
	"socialapi/models"

	"github.com/koding/bongo"
)

type BotChannelRequest struct {
	GroupName string
	Username  string
}

func (b *BotChannelRequest) validate() error {
	if b.GroupName == "" {
		return ErrGroupNotSet
	}

	if b.Username == "" {
		return ErrUsernameNotSet
	}

	return nil
}

func (b *BotChannelRequest) verifyAccount() (*models.Account, error) {

	// fetch account id
	acc := models.NewAccount()
	err := acc.ByNick(b.Username)
	if err == bongo.RecordNotFound {
		return nil, ErrAccountNotFound
	}

	if err != nil {
		return nil, err
	}

	return acc, nil
}

func (b *BotChannelRequest) verifyGroup() (*models.Channel, error) {
	c := models.NewChannel()

	selector := map[string]interface{}{
		"type_constant": models.Channel_TYPE_GROUP,
		"group_name":    b.GroupName,
	}

	err := c.One(bongo.NewQS(selector))
	if err == bongo.RecordNotFound {
		return nil, ErrGroupNotFound
	}

	if err != nil {
		return nil, err
	}

	return c, nil
}
