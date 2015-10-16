package services

import (
	"fmt"

	"code.google.com/p/go-uuid/uuid"
	"github.com/jmoiron/sqlx"
)

type eventType int8

func (e eventType) String() string {
	names := []string{"listUpdatedEvent", "listMetaAddedEvent", "listMetaUpdatedEvent", "listMetaDeletedEvent", "pointAddedToListEvent", "pointMovedFromListEvent", "pointUpdatedEvent", "pointUserDataUpdatedEvent", "pointMetaAddedEvent", "pointMetaUpdatedEvent", "pointMetaDeletedEvent"}
	return names[e-1]
}

const (
	_                                 = iota
	listUpdatedEvent        eventType = iota // 1
	listMetaAddedEvent                       // 2
	listMetaUpdatedEvent                     // 3
	listMetaDeletedEvent                     // 4
	pointAddedToListEvent                    // 5
	pointMovedFromListEvent                  // 6
	pointUpdatedEvent                        // 7
	pointMetaAddedEvent                      // 9
	pointMetaUpdatedEvent                    // 10
	pointMetaDeletedEvent                    // 11
)

type event struct {
	event eventType

	identifier1 string
	identifier2 string
}

/**
 * Database access functions
 */

func addEventForList(tx *sqlx.Tx, list string, event *event) error {
	identifier := fmt.Sprintf("%s", uuid.NewUUID())
	_, err := tx.Exec("select create_event_for_list($1, $2, $3, $4, $5)", list, identifier, event.event, event.identifier1, event.identifier2)
	return err
}

func addEventForpoint(tx *sqlx.Tx, point string, event *event) error {
	fmt.Println(event)
	identifier := fmt.Sprintf("%s", uuid.NewUUID())
	_, err := tx.Exec("select create_event_for_point($1, $2, $3, $4, $5)", point, identifier, event.event, event.identifier1, event.identifier2)
	return err
}

func addEventForpointMeta(tx *sqlx.Tx, pointMeta string, event *event) error {
	identifier := fmt.Sprintf("%s", uuid.NewUUID())
	_, err := tx.Exec("select create_event_for_point_meta($1, $2, $3, $4, $5)", pointMeta, identifier, event.event, event.identifier1, event.identifier2)
	return err
}

func addEventForListMeta(tx *sqlx.Tx, listMeta string, event *event) error {
	identifier := fmt.Sprintf("%s", uuid.NewUUID())
	_, err := tx.Exec("select create_event_for_list_meta($1, $2, $3, $4, $5)", listMeta, identifier, event.event, event.identifier1, event.identifier2)
	return err
}
