package services

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/lib/pq"
)

/**
 * Consume event service
 */

type consumeEventRequestParams struct {
	Geohash       string `form:"geohash"`
	LastEventDate string `form:"last_date"`
	LastDateOnly  bool   `form:"last_date_only"`
	List          string `form:"list"`
}

type consumeEventRequest struct {
	consumeEventRequestParams
}

type consumeEventModel struct {
	Id                uint64    `json:"id"`
	Date              time.Time `json:"date"`
	Event             eventType `json:"event"`
	ObjectIdentifier  string    `db:"object_identifier" json:"object_identifier"`
	ObjectIdentifier2 string    `db:"object_identifier2" json:"object_identifier2"`
}

type JSONTime time.Time

func (jt JSONTime) MarshalJSON() ([]byte, error) {
	loc, err := time.LoadLocation("GMT")
	if err != nil {
		return nil, err
	}
	t := time.Time(jt).In(loc)
	stamp := fmt.Sprintf("\"%s\"", t.Format("2006-01-02T15:04:05.999Z"))
	return []byte(stamp), nil
}

type lastEventDateResponse struct {
	NullLastDate pq.NullTime `db:"last_date" json:"-"`
	LastDate     JSONTime    `json:"last_date"`
}

func consumeEventHandler(c *gin.Context) {
	request := consumeEventRequest{}
	if err := c.Bind(&request.consumeEventRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	var lastEventDate *time.Time = nil
	if len(request.LastEventDate) > 0 {
		if date, err := time.Parse(time.RFC3339Nano, request.LastEventDate); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusBadRequest)
			return
		} else {
			lastEventDate = &date
		}
	}

	var modelToEncode interface{}

	if request.LastDateOnly {
		lastEventDateResponse := lastEventDateResponse{}
		if err := db.Get(&lastEventDateResponse, "select * from last_event_date($1, $2, $3)", request.List, request.Geohash, lastEventDate); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
		if lastEventDateResponse.NullLastDate.Valid != true {
			t := time.Now()
			lastEventDateResponse.LastDate = JSONTime(t)
		} else {
			lastEventDateResponse.LastDate = JSONTime(lastEventDateResponse.NullLastDate.Time)
		}
		modelToEncode = lastEventDateResponse
	} else {
		events := []*consumeEventModel{}
		if err := db.Select(&events, "select * from consume_event($1, $2, $3)", request.List, request.Geohash, lastEventDate); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
		modelToEncode = events
	}

	c.JSON(http.StatusOK, &modelToEncode)
}
