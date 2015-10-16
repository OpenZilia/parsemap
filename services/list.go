package services

import (
	"fmt"
	"math"
	"net/http"
	"time"

	"git.ccsas.biz/geohash"
	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"gopkg.in/guregu/null.v2"
)

const maxListZoneNPoints int = 200

/**
 * Fetch points from list
 */

type fetchListPointRequestParams struct {
	ExcludeGeohash []string `form:"eg[]"`
	Geohash        string   `form:"geohash" binding:"required"`
	LastPointDate  string   `form:"last_point_date"`
	Limit          int      `form:"limit"`
}

type fetchListPointRequest struct {
	fetchListPointRequestParams

	list string
}

func fetchListPointHandler(c *gin.Context) {
	request := fetchListPointRequest{}

	if err := c.Bind(&request.fetchListPointRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.list = c.Params.ByName("list")

	if request.Limit > 50 {
		request.Limit = 50
	}

	if len(request.Geohash) > geohash.MaxGeohashLength {
		outputJSONError(c.Writer, fmt.Sprintf("Wrong geohash length, must be %d digits", geohash.MaxGeohashLength), http.StatusBadRequest)
		return
	}

	var lastPointDate time.Time
	if len(request.LastPointDate) > 0 {
		if date, err := time.Parse(time.RFC3339Nano, request.LastPointDate); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusBadRequest)
			return
		} else {
			lastPointDate = date
		}
	}

	for index, excludeGeohash := range request.ExcludeGeohash {
		request.ExcludeGeohash[index] = fmt.Sprintf("%s%%", excludeGeohash)
	}
	excludeGeohashArray := generateSQLStringArray(request.ExcludeGeohash)
	query := fmt.Sprintf("select * from get_list_point($1, $2, '%s', $3, $4)", excludeGeohashArray)

	points := []*fetchPointModel{}
	if err := db.Select(&points, query, request.list, request.Geohash, lastPointDate, request.Limit); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := associateMetasForPoints(points, request.list); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.JSON(http.StatusOK, points)
}

/**
 * fetch lists for events
 */

type fetchListsForEventsRequestParams struct {
	EventIds []int `form:"e[]" binding:"required"`
}

type fetchListsForEventsRequest struct {
	fetchListsForEventsRequestParams
}

type fetchListsForEventsModel struct {
	Identifier   string `json:"identifier"`
	Name         string `json:"name"`
	Icon         string `json:"icon"`
	Author       string `json:"author"`
	AuthorId     string `json:"author_id" db:"author_id"`
	IsDefault    bool   `json:"is_default" db:"is_default"`
	IsOwned      bool   `json:"is_owned" db:"is_owned"`
	Notification bool   `json:"notification"`

	Metas []*listMetaModel `json:"metas"`
}

func fetchListsForEventsHandler(c *gin.Context) {
	request := fetchListsForEventsRequest{}

	if err := c.Bind(&request.fetchListsForEventsRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	eventIds := makeUint64ArrayWithIntArray(request.EventIds)
	arrayQuery := generateSQLIntArray(eventIds)
	query := fmt.Sprintf("select * from get_list_for_events('%s')", arrayQuery)

	lists := []*fetchListsForEventsModel{}
	if err := db.Select(&lists, query); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	for _, list := range lists {
		if err := db.Select(&list.Metas, "select * from get_list_metas($1)", list.Identifier); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
	}

	c.JSON(http.StatusOK, &lists)
}

/**
 * fetch list meta for events
 */

type fetchListMetasForEventsRequest struct {
	EventIds []int `form:"e[]" binding:"required"`
}

type fetchListMetasForEventsModel struct {
	Identifier string `json:"identifier"`
	Uid        string `json:"uid"`
	Action     string `json:"action"`
	Content    string `json:"content"`
}

func fetchListMetasForEventsHandler(c *gin.Context) {
	request := fetchListMetasForEventsRequest{}

	if err := c.Bind(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	eventIds := makeUint64ArrayWithIntArray(request.EventIds)
	arrayQuery := generateSQLIntArray(eventIds)
	query := fmt.Sprintf("select * from get_list_metas_for_events('%s')", arrayQuery)

	metas := []*fetchListMetasForEventsModel{}
	if err := db.Select(&metas, query); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.JSON(http.StatusOK, &metas)
}

/**
 * Get list zones
 * TODO: make configurable from request (maxListZoneNPoints etc...)
 * possibility to provide geohash length
 */

type listZoneModel struct {
	Geohash   string  `json:"geohash"`
	NPoints   int     `db:"n_points" json:"n_points"`
	Latitude  float64 `db:"avg_latitude" json:"latitude"`
	Longitude float64 `db:"avg_longitude" json:"longitude"`
}

func cleanupGeohashZonesTree(zones []*listZoneModel) []*listZoneModel {

	resultArray := make([]*listZoneModel, 0, 200)
	geohashMap := map[string]bool{}

	for _, zone := range zones {
		if zone.NPoints > maxListZoneNPoints {
			continue
		}
		canAdd := true
		for i := len(zone.Geohash) - 1; i >= 5; i-- {
			if _, ok := geohashMap[zone.Geohash[:i]]; ok == true {
				canAdd = false
			}
		}
		if canAdd {
			geohashMap[zone.Geohash] = true
			resultArray = append(resultArray, zone)
		}
	}
	return resultArray
}

func fetchListGeohashZones(c *gin.Context) {
	list := c.Params.ByName("list")

	zones := []*listZoneModel{}
	if err := db.Select(&zones, "SELECT * from get_list_geohash_zones($1, $2)", list, maxListZoneNPoints); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	resultArray := cleanupGeohashZonesTree(zones)

	c.JSON(http.StatusOK, &resultArray)
}

/**
 *	Map annotation cluster management
 */

type fetchMapAnnotationRequestParams struct {
	LatitudeMin      float64 `form:"latitudeMin" binding:"required"`
	LongitudeMin     float64 `form:"longitudeMin" binding:"required"`
	LatitudeMax      float64 `form:"latitudeMax" binding:"required"`
	LongitudeMax     float64 `form:"longitudeMax" binding:"required"`
	PixelWidth       float64 `form:"pixelWidth" binding:"required"`
	PixelHeight      float64 `form:"pixelHeight" binding:"required"`
	AnnotationWidth  float64 `form:"annotationWidth" binding:"required"`
	AnnotationHeight float64 `form:"annotationHeight" binding:"required"`
}

type fetchMapAnnotationRequest struct {
	fetchMapAnnotationRequestParams

	list string
}

type fetchMapAnnotationsResults struct {
	Clusters []*listZoneModel   `json:"clusters"`
	Points   []*fetchPointModel `json:"points"`
}

func fetchMapAnnotations(c *gin.Context) {
	request := fetchMapAnnotationRequest{}

	if err := c.BindWith(&request.fetchMapAnnotationRequestParams, binding.Form); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.list = c.Params.ByName("list")

	maxHorAnnotations := request.PixelWidth / (request.AnnotationWidth * 2)
	maxVerAnnotations := request.PixelHeight / (request.AnnotationHeight * 2)

	var anglePerAnnotation float64
	latDiff := request.LatitudeMax - request.LatitudeMin
	longDiff := request.LongitudeMax - request.LongitudeMin

	maxAnnotations := math.Max(maxHorAnnotations, maxVerAnnotations)
	if maxHorAnnotations > maxVerAnnotations {
		anglePerAnnotation = longDiff / maxAnnotations
	} else {
		anglePerAnnotation = latDiff / maxAnnotations
	}

	geohashLength := int(math.Log(180/anglePerAnnotation) / math.Log(2))
	if geohashLength > 17 {
		geohashLength = 17
	} else if geohashLength < 5 {
		geohashLength = 5
	}

	zones := []*listZoneModel{}
	from_nodes_size := geohashLength - 1
	from_nodes := geohash.CoordinatesBoundsToGeohashes(request.LatitudeMin, request.LongitudeMin, request.LatitudeMax, request.LongitudeMax, from_nodes_size)
	query := fmt.Sprintf("SELECT * from get_zone_tree_level($1, $2, '%s', $3)", generateSQLStringArray(from_nodes))
	if err := db.Select(&zones, query, request.list, geohashLength, from_nodes_size); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	result := fetchMapAnnotationsResults{
		[]*listZoneModel{},
		[]*fetchPointModel{},
	}
	geohashes := "("
	nPoints := 0
	for _, zone := range zones {
		if zone.NPoints <= 4 || geohashLength == 17 {
			geohashes = fmt.Sprintf("%s%s|", geohashes, zone.Geohash)
			nPoints += zone.NPoints
		} else {
			result.Clusters = append(result.Clusters, zone)
		}
	}

	if geohashes != "(" {
		geohashes = geohashes[:len(geohashes)-1] + ")"
		if err := db.Select(&result.Points, "select * from get_list_point($1, $2, '{}', $3, $4)", request.list, geohashes, time.Time{}, nPoints); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
		if err := associateMetasForPoints(result.Points, request.list); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
	}

	c.JSON(http.StatusOK, &result)
}

/**
 * Get complete list infos
 */

type listMetaModel struct {
	Identifier string `json:"identifier"`
	Uid        string `json:"uid"`
	Action     string `json:"action"`
	Content    string `json:"content"`
}

type completeListInfoModel struct {
	Name         string    `json:"name"`
	Icon         string    `json:"icon"`
	NPoints      int       `json:"n_points" db:"n_points"`
	NInstalls    int       `json:"n_installs" db:"n_installs"`
	LastUpdate   time.Time `json:"last_update" db:"last_update"`
	Author       string    `json:"author"`
	AuthorId     string    `json:"author_id" db:"author_id"`
	IsDefault    bool      `json:"is_default" db:"is_default"`
	IsOwned      bool      `json:"is_owned" db:"is_owned"`
	Notification bool      `json:"notification"`

	Metas []*listMetaModel `json:"metas"`
}

func getCompleteListInfoHandler(c *gin.Context) {
	list := c.Params.ByName("list")

	listInfos := completeListInfoModel{}
	if err := db.Get(&listInfos, "select * from get_complete_list_infos($1)", list); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := db.Select(&listInfos.Metas, "select * from get_list_metas($1)", list); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.JSON(http.StatusOK, &listInfos)
}

/**
 * Get installed lists
 */

type installedListModel struct {
	Identifier   string `json:"identifier"`
	Name         string `json:"name"`
	Icon         string `json:"icon"`
	Author       string `json:"author"`
	AuthorId     string `json:"author_id" db:"author_id"`
	Notification bool   `json:"notification"`
	IsDefault    bool   `json:"is_default" db:"is_default"`
	IsOwned      bool   `json:"is_owned" db:"is_owned"`

	Metas []*listMetaModel `json:"metas"`
}

func getInstalledListsHandler(c *gin.Context) {
	lists := []*installedListModel{}
	if err := db.Select(&lists, "select * from get_installed_lists()"); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	for _, list := range lists {
		if err := db.Select(&list.Metas, "select * from get_list_metas($1)", list.Identifier); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}
	}

	c.JSON(http.StatusOK, &lists)
}

/**
 * List creation service
 */

type CreateListRequestParams struct {
	Name string `binding:"required"`
	Icon string `json:"icon"`
}

type createListRequest struct {
	CreateListRequestParams

	version string
}

type CreateListResponse struct {
	Identifier string `json:"identifier"`
}

func createList(request *createListRequest) (string, error) {
	identifier := newUUID()

	_, err := db.Exec("select create_list($1, $2, $3, $4)", identifier, request.Name, request.Icon, request.version)
	if err != nil {
		return "", err
	}
	return identifier, nil
}

func createListHandler(c *gin.Context) {
	request := createListRequest{}

	if err := c.Bind(&request.CreateListRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.version = c.MustGet("version").(string)

	identifier, err := createList(&request)
	if err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	response := CreateListResponse{Identifier: identifier}
	c.JSON(http.StatusCreated, &response)
}

/**
 * Update list meta service
 */

type updateListRequestParams struct {
	Name null.String
	Icon null.String
}

type updateListRequest struct {
	updateListRequestParams

	list string
}

func updateList(request *updateListRequest) error {
	_, err := db.Exec("select update_list($1, $2, $3)", request.list, request.Name, request.Icon)
	if err != nil {
		return err
	}
	return nil
}

func updateListHandler(c *gin.Context) {
	request := updateListRequest{}

	if err := c.Bind(&request.updateListRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.list = c.Params.ByName("list")

	if err := updateList(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusCreated)
}

/**
 * List add point service
 */

type addPointToListRequestParams struct {
	NoEvent bool `form:"no_event"`

	ReturnZone bool `form:"return_zone"`
}

type addPointToListRequest struct {
	addPointToListRequestParams

	point string
	list  string
}

func addPointToList(request *addPointToListRequest) error {
	_, err := db.Exec("select add_point_to_list($1, $2, $3)", request.point, request.list, request.NoEvent)
	if err != nil {
		return err
	}
	return nil
}

func addPointToListHandler(c *gin.Context) {
	request := addPointToListRequest{}

	if err := c.Bind(&request.addPointToListRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	if err := c.BindWith(&request.addPointToListRequestParams, binding.Form); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.list = c.Params.ByName("list")
	request.point = c.Params.ByName("point")

	if err := addPointToList(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	if request.ReturnZone == false {
		c.Writer.Header().Set("Content-Type", "application/json")
		c.Writer.WriteHeader(http.StatusCreated)
	} else {
		listZoneModel := listZoneModel{}
		if err := db.Get(&listZoneModel, "select * from get_list_geohash_zones_for_point($1, $2, $3)", request.list, request.point, maxListZoneNPoints); err != nil {
			outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
			return
		}

		c.JSON(http.StatusCreated, &listZoneModel)
	}

}

/**
 * List remove point service
 */

type removePointFromListRequest struct {
	point string
	list  string
}

func removePointFromList(request *removePointFromListRequest) error {
	_, err := db.Exec("select remove_point_from_list($1, $2, false)", request.point, request.list)
	if err != nil {
		return err
	}
	return nil
}

func removePointFromListHandler(c *gin.Context) {
	request := removePointFromListRequest{}
	request.list = c.Params.ByName("list")
	request.point = c.Params.ByName("point")

	if err := removePointFromList(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusOK)
}

/**
 * Create list meta services
 */

type createListMetaRequestParams struct {
	Uid     string `binding:"required"`
	Action  string `binding:"required"`
	Content string `binding:"required"`
	List    string `binding:"required"`
}

type createListMetaRequest struct {
	createListMetaRequestParams
}

type createListMetaResponse struct {
	Identifier string `json:"identifier"`
}

func createListMeta(request *createListMetaRequest) (string, error) {
	identifier := newUUID()

	_, err := db.Exec("select create_list_meta($1, $2, $3, $4, $5)", identifier, request.List, request.Uid, request.Action, request.Content)
	if err != nil {
		return "", err
	}
	return identifier, nil
}

func createListMetaHandler(c *gin.Context) {
	request := createListMetaRequest{}

	if err := c.Bind(&request.createListMetaRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	identifier, err := createListMeta(&request)
	if err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}
	response := createListMetaResponse{Identifier: identifier}
	c.JSON(http.StatusCreated, &response)
}

/**
 * Update list meta service
 */

type updateListMetaRequestParams struct {
	Uid     string `binding:"required"`
	Action  string `binding:"required"`
	Content string `binding:"required"`
}

type updateListMetaRequest struct {
	updateListMetaRequestParams

	meta string
}

func updateListMeta(request *updateListMetaRequest) error {
	_, err := db.Exec("select update_list_meta($1, $2, $3, $4)", request.meta, request.Uid, request.Action, request.Content)
	if err != nil {
		return err
	}
	return nil
}

func updateListMetaHandler(c *gin.Context) {
	request := updateListMetaRequest{}

	if err := c.Bind(&request.updateListMetaRequestParams); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	request.meta = c.Params.ByName("meta")

	if err := updateListMeta(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusOK)
}

/**
 * Remove list meta services
 */

type removeListMetaRequest struct {
	meta string
}

func removeListMeta(request *removeListMetaRequest) error {
	_, err := db.Exec("select delete_list_meta($1)", request.meta)
	if err != nil {
		return err
	}
	return nil
}

func removeListMetaHandler(c *gin.Context) {
	request := removeListMetaRequest{}
	request.meta = c.Params.ByName("meta")

	if err := removeListMeta(&request); err != nil {
		outputJSONErrorCheckType(c.Writer, err, http.StatusInternalServerError)
		return
	}

	c.Writer.Header().Set("Content-Type", "application/json")
	c.Writer.WriteHeader(http.StatusOK)
}
