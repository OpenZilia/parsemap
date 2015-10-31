package services

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/vitaminwater/geohash"
	"gopkg.in/guregu/null.v2"
)

/**
 * Fetch pointes for events
 */

type fetchPointsForEventsRequestParams struct {
	EventIds []int  `form:"e[]" binding:"required"`
	List     string `form:"list" binding:"required"`
}

type fetchPointsForEventsRequest struct {
	fetchPointsForEventsRequestParams
}

type fetchListPointMetaModel struct {
	PointId uint64 `db:"point_id" json:"-"`

	Identifier string      `json:"identifier"`
	Uid        string      `json:"uid"`
	Action     string      `json:"action"`
	Content    string      `json:"content"`
	List       null.String `json:"list"`
}

type fetchPointModel struct {
	Id          uint64    `json:"-"`
	Identifier  string    `json:"identifier"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	Name        string    `json:"name"`
	Provider    string    `json:"provider"`
	ProviderId  string    `db:"provider_id" json:"provider_id"`
	DateCreated time.Time `db:"date_created" json:"date_created"`

	Metas []*fetchListPointMetaModel `json:"metas"`
}

func fetchPointsForEventsHandler(c *gin.Context) {
	request := fetchPointsForEventsRequest{}

	if err := c.Bind(&request.fetchPointsForEventsRequestParams); err != nil {
		return
	}

	eventIds := makeUint64ArrayWithIntArray(request.EventIds)
	arrayQuery := generateSQLIntArray(eventIds)
	query := fmt.Sprintf("select * from get_pointes_for_events('%s')", arrayQuery)

	pointes := []*fetchPointModel{}
	if err := db.Select(&pointes, query); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := associateMetasForPoints(pointes, request.List); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.JSON(http.StatusOK, pointes)
}

func associateMetasForPoints(pointes []*fetchPointModel, list string) error {
	point_ids := make([]uint64, len(pointes))
	for _, point := range pointes {
		point_ids = append(point_ids, point.Id)
	}

	arrayQuery := generateSQLIntArray(point_ids)
	query := fmt.Sprintf("select * from get_metas_for_point_ids('%s', $1)", arrayQuery)

	metas := []*fetchListPointMetaModel{}
	if err := db.Select(&metas, query, list); err != nil {
		return err
	}

	var (
		index uint64 = 0
		meta  *fetchListPointMetaModel
	)
	for _, point := range pointes {
		point.Metas = []*fetchListPointMetaModel{}
		for _, meta = range metas[index:] {
			if meta.PointId != point.Id {
				break
			}
			point.Metas = append(point.Metas, meta)
			index += 1
		}
	}
	return nil
}

/**
 * fetch point meta for events
 */

type fetchPointMetasForEventsRequest struct {
	EventIds []int `form:"e[]" binding:"required"`
}

type fetchPointMetasForEventsModel struct {
	Identifier string      `json:"identifier"`
	Uid        string      `json:"uid"`
	Action     string      `json:"action"`
	Content    string      `json:"content"`
	List       null.String `json:"list"`
}

func fetchPointMetasForEventsHandler(c *gin.Context) {
	request := fetchPointMetasForEventsRequest{}

	if err := c.Bind(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	fmt.Println(request.EventIds)
	eventIds := makeUint64ArrayWithIntArray(request.EventIds)
	arrayQuery := generateSQLIntArray(eventIds)
	query := fmt.Sprintf("select * from get_point_metas_for_events('%s')", arrayQuery)

	metas := []*fetchPointMetasForEventsModel{}
	if err := db.Select(&metas, query); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.JSON(http.StatusOK, &metas)
}

/**
 * Point creation service
 */

type CreatePointRequestParams struct {
	Name string `json:"name" binding:"required"`

	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`

	Provider   string `json:"provider" binding:"required"`
	ProviderId string `json:"provider_id"`
}

type createPointRequest struct {
	CreatePointRequestParams

	version string
}

type CreatePointResponse struct {
	Identifier string `json:"identifier"`
}

func createPoint(request *createPointRequest) (string, error) {
	identifier := newUUID()

	geohash := geohash.GeohashFromCoordinates(request.Latitude, request.Longitude)

	if _, err := db.Exec("select * from create_point($1, $2, $3, $4, $5, $6, $7, $8)", identifier, geohash, request.Latitude, request.Longitude, request.Name, request.Provider, request.ProviderId, request.version); err != nil {
		return "", err
	}
	return identifier, nil
}

func createPointHandler(c *gin.Context) {
	request := createPointRequest{}

	if err := c.Bind(&request.CreatePointRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.version = c.MustGet("version").(string)

	identifier, err := createPoint(&request)
	if err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	response := CreatePointResponse{Identifier: identifier}

	c.JSON(http.StatusCreated, &response)
}

/**
 * Update point service
 */

type updatePointRequestParams struct {
	Name  null.String
	Point null.String

	Latitude  null.Float
	Longitude null.Float

	NoEvent bool `form:"no_event"`
}

type updatePointRequest struct {
	updatePointRequestParams

	point string
}

func updatePoint(request *updatePointRequest) error {
	if request.Latitude.Valid == false || request.Longitude.Valid == false {
		request.Latitude.Valid = false
		request.Longitude.Valid = false
	}

	var geohashString null.String = null.NewString("", false)
	if request.Latitude.Valid == true && request.Longitude.Valid == true {
		geohashString.SetValid(geohash.GeohashFromCoordinates(request.Latitude.Float64, request.Longitude.Float64))
	}

	_, err := db.Exec("select update_point($1, $2, $3, $4, $5, $6, $7)", request.point, request.Name, request.Point, geohashString, request.Latitude, request.Longitude, request.NoEvent)
	if err != nil {
		return err
	}
	return nil
}

func updatePointHandler(c *gin.Context) {
	request := updatePointRequest{}

	if err := c.Bind(&request.updatePointRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := c.BindWith(&request.updatePointRequestParams, binding.Form); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.point = c.Params.ByName("point")

	if err := updatePoint(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusCreated)
}

/**
 * Remove point services
 */

type removePointRequest struct {
	point string
}

func removePoint(request *removePointRequest) error {
	_, err := db.Exec("select delete_point($1)", request.point)
	if err != nil {
		return err
	}
	return nil
}

func removePointHandler(c *gin.Context) {
	request := &removePointRequest{}
	request.point = c.Params.ByName("point")

	if err := removePoint(request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusAccepted)
}

/**
 * Create point meta services
 */

type createPointMetaRequestParams struct {
	List  string
	Point string `binding:"required"`

	Uid     string `binding:"required"`
	Action  string `binding:"required"`
	Content string `binding:"required"`

	NoEvent bool `form:"no_event"`
}

type createPointMetaRequest struct {
	createPointMetaRequestParams
}

type createPointMetaResponse struct {
	Identifier string `json:"identifier"`
}

func createPointMeta(cam *createPointMetaRequest) (string, error) {
	identifier := newUUID()

	_, err := db.Exec("select create_point_meta($1, $2, $3, $4, $5, $6, $7)", identifier, cam.Point, cam.List, cam.Action, cam.Uid, cam.Content, cam.NoEvent)
	if err != nil {
		return "", err
	}
	return identifier, nil
}

func createPointMetaHandler(c *gin.Context) {
	request := createPointMetaRequest{}

	if err := c.Bind(&request.createPointMetaRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := c.BindWith(&request.createPointMetaRequestParams, binding.Form); err != nil {
		return
	}

	identifier, err := createPointMeta(&request)
	if err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	response := &createPointMetaResponse{Identifier: identifier}

	c.JSON(http.StatusCreated, &response)
}

/**
 * Update point meta service
 */

type updatePointMetaRequestParams struct {
	Uid     string `binding:"required"`
	Action  string `binding:"required"`
	Content string `binding:"required"`
}

type updatePointMetaRequest struct {
	updatePointMetaRequestParams

	meta string
}

func updatePointMeta(request *updatePointMetaRequest) error {
	_, err := db.Exec("select update_point_meta($1, $2, $3, $4)", request.meta, request.Uid, request.Action, request.Content)
	if err != nil {
		return err
	}
	return nil
}

func updatePointMetaHandler(c *gin.Context) {
	request := updatePointMetaRequest{}

	if err := c.Bind(&request.updatePointMetaRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.meta = c.Params.ByName("meta")

	if err := updatePointMeta(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusNoContent)
}

/**
 * Remove point meta services
 */

type removePointMetaRequest struct {
	meta string
}

func removePointMeta(request *removePointMetaRequest) error {
	_, err := db.Exec("select delete_point_meta($1)", request.meta)
	if err != nil {
		return err
	}
	return nil
}

func removePointMetaHandler(c *gin.Context) {
	request := &removePointMetaRequest{}
	request.meta = c.Params.ByName("meta")

	if err := removePointMeta(request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusAccepted)
}
